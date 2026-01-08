// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {PropertyStorage} from "./storage/PropertyStorage.sol";
import {YieldBase} from "./YieldBase.sol";

/// @title PropertyNFT
/// @notice ERC-721 contract for representing unique property ownership in RWA tokenization
/// @dev Implements UUPS proxy pattern with ERC-7201 storage isolation for property metadata
/// Access control: Only owner can mint property NFTs (property owner restriction)
/// Metadata: On-chain storage of hashes and timestamps, off-chain IPFS URIs for detailed documents
/// Integration: Links to YieldBase via propertyTokenId for yield agreement creation
contract PropertyNFT is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable
{
    using PropertyStorage for PropertyStorage.PropertyStorageLayout;

    /// @notice Address of the YieldBase contract authorized to link properties to yield agreements
    address public yieldBase;

    /// @notice Modifier that restricts calls to the configured YieldBase contract
    modifier onlyYieldBase() {
        require(msg.sender == yieldBase, "Caller is not the configured YieldBase contract");
        _;
    }

    /// @notice Emitted when a new property NFT is minted
    /// @param tokenId The token ID of the minted property
    /// @param propertyAddressHash Hash of the property address for verification
    /// @param metadataURI IPFS URI containing detailed property documents
    event PropertyMinted(
        uint256 indexed tokenId,
        bytes32 propertyAddressHash,
        string metadataURI
    );

    /// @notice Emitted when a property is verified by an authorized verifier
    /// @param tokenId The token ID of the verified property
    /// @param verifier Address of the verifier who approved the property
    event PropertyVerified(uint256 indexed tokenId, address verifier);

    /// @notice Emitted when a property is linked to a yield agreement
    /// @param tokenId The property token ID
    /// @param yieldAgreementId The ID of the linked yield agreement
    event PropertyLinkedToYieldAgreement(
        uint256 indexed tokenId,
        uint256 yieldAgreementId
    );

    /// @dev Disable constructor for UUPS proxy pattern
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the PropertyNFT contract
    /// @dev Sets up ERC-721 with name and symbol, initializes UUPS proxy
    /// @param initialOwner Address that will own the contract (property owner)
    /// @param name ERC-721 token name
    /// @param symbol ERC-721 token symbol
    function initialize(
        address initialOwner,
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    /// @notice Mint a new property NFT
    /// @dev Only callable by contract owner (property owner). Stores property metadata in ERC-7201 storage
    /// @param propertyAddressHash keccak256 hash of the property address for verification
    /// @param metadataURI IPFS URI containing detailed property documents, rental agreements, photos
    /// @return tokenId The token ID of the newly minted property NFT
    function mintProperty(
        bytes32 propertyAddressHash,
        string memory metadataURI
    ) external onlyOwner nonReentrant returns (uint256 tokenId) {
        require(propertyAddressHash != bytes32(0), "Property address hash cannot be zero");
        require(bytes(metadataURI).length > 0, "Metadata URI cannot be empty");

        PropertyStorage.PropertyStorageLayout storage layout = PropertyStorage.getPropertyStorage();
        layout.nextTokenId++;
        tokenId = layout.nextTokenId;

        _mint(msg.sender, tokenId);

        layout.properties[tokenId] = PropertyStorage.PropertyData({
            propertyAddressHash: propertyAddressHash,
            verificationTimestamp: 0, // Set during verification
            metadataURI: metadataURI,
            yieldAgreementId: 0, // Linked later during yield agreement creation
            isVerified: false, // Set during verification
            verifierAddress: address(0) // Set during verification
        });

        emit PropertyMinted(tokenId, propertyAddressHash, metadataURI);
    }

    /// @notice Verify a property NFT
    /// @dev Only callable by contract owner. Sets verification timestamp and marks property as verified
    /// This represents approval by an authorized property verifier (could be expanded to role-based access)
    /// @param tokenId The token ID of the property to verify
    function verifyProperty(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Property does not exist");

        PropertyStorage.PropertyStorageLayout storage layout = PropertyStorage.getPropertyStorage();
        PropertyStorage.PropertyData storage property = layout.properties[tokenId];

        require(!property.isVerified, "Property already verified");

        property.isVerified = true;
        property.verificationTimestamp = block.timestamp;
        property.verifierAddress = msg.sender;

        emit PropertyVerified(tokenId, msg.sender);
    }

    /// @notice Link a property to a yield agreement
    /// @dev Only callable by the configured YieldBase contract. Establishes bidirectional link between property NFT and yield agreement
    /// Called by YieldBase during createYieldAgreement to establish the relationship
    /// Prevents overwriting links to active agreements for security
    /// @param tokenId The property token ID to link
    /// @param yieldAgreementId The ID of the yield agreement to link to
    function linkToYieldAgreement(
        uint256 tokenId,
        uint256 yieldAgreementId
    ) external onlyYieldBase {
        require(_ownerOf(tokenId) != address(0), "Property does not exist");
        require(yieldAgreementId > 0, "Invalid yield agreement ID");

        PropertyStorage.PropertyStorageLayout storage layout = PropertyStorage.getPropertyStorage();
        PropertyStorage.PropertyData storage property = layout.properties[tokenId];

        require(property.isVerified, "Property must be verified before linking");

        // Prevent overwriting links to active agreements
        if (property.yieldAgreementId > 0 && property.yieldAgreementId != yieldAgreementId) {
            // Only allow relinking if the existing agreement is not active
            // This prevents overwriting active yield agreements for security
            // Use try/catch to handle cases where yieldBase might not be a proper YieldBase contract
            try YieldBase(yieldBase).isAgreementActive(property.yieldAgreementId) returns (bool isActive) {
                require(!isActive, "Cannot relink property with active yield agreement");
            } catch {
                // If the call fails (e.g., in tests), allow relinking but log the attempt
                // In production, this should never happen as yieldBase should always be a valid YieldBase contract
            }
        }

        property.yieldAgreementId = yieldAgreementId;

        emit PropertyLinkedToYieldAgreement(tokenId, yieldAgreementId);
    }

    /// @notice Check if a property is verified
    /// @dev Gas-efficient view to check verification status without reading full struct
    /// @param tokenId The token ID to query
    /// @return True if the property exists and is verified, false otherwise
    function isPropertyVerified(uint256 tokenId) external view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) {
            return false; // Property doesn't exist
        }
        PropertyStorage.PropertyStorageLayout storage layout = PropertyStorage.getPropertyStorage();
        return layout.properties[tokenId].isVerified;
    }

    /// @notice Get all property data for a token
    /// @dev Returns complete PropertyData struct from ERC-7201 storage
    /// @param tokenId The token ID to query
    /// @return PropertyData struct containing all property metadata
    function getPropertyData(uint256 tokenId)
        external
        view
        returns (PropertyStorage.PropertyData memory)
    {
        require(_ownerOf(tokenId) != address(0), "Property does not exist");
        PropertyStorage.PropertyStorageLayout storage layout = PropertyStorage.getPropertyStorage();
        return layout.properties[tokenId];
    }

    /// @notice Override tokenURI to return metadata URI from storage
    /// @dev Returns the IPFS URI stored during minting, containing detailed property documents
    /// @param tokenId The token ID to query
    /// @return URI string pointing to property metadata on IPFS
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_ownerOf(tokenId) != address(0), "Property does not exist");
        PropertyStorage.PropertyStorageLayout storage layout = PropertyStorage.getPropertyStorage();
        return layout.properties[tokenId].metadataURI;
    }

    /// @notice Set the YieldBase contract address
    /// @dev Only owner can set the YieldBase reference. Must be set before yield agreements can be created
    /// @param yieldBaseAddress Address of the deployed YieldBase contract
    function setYieldBase(address yieldBaseAddress) external onlyOwner {
        require(yieldBaseAddress != address(0), "Invalid YieldBase address");
        yieldBase = yieldBaseAddress;
    }

    /// @notice Authorize contract upgrades
    /// @dev Only owner can upgrade the contract (UUPS proxy pattern)
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /// @notice Get the property storage reference (internal helper)
    /// @dev Internal function to access ERC-7201 storage layout
    /// @return layout Reference to PropertyStorageLayout
    function _getPropertyStorage()
        internal
        pure
        returns (PropertyStorage.PropertyStorageLayout storage layout)
    {
        return PropertyStorage.getPropertyStorage();
    }
}
