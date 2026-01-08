// Token standard toggle component using bubble/chip format like ETH price display

import React from 'react';
import {
  Chip,
  Menu,
  MenuItem,
  Tooltip,
  Box,
} from '@mui/material';
import { useTokenStandard } from '../context/TokenStandardContext';

/**
 * TokenStandardToggle component for switching between ERC-721 + ERC-20 and ERC-1155
 * Uses bubble/chip format similar to ETH price display for better visibility
 * @returns {React.ReactElement} Chip-based toggle component
 */
function TokenStandardToggle() {
  const { tokenStandard, setTokenStandard, getLabel, getDescription } = useTokenStandard();
  const [anchorEl, setAnchorEl] = React.useState(null);
  const open = Boolean(anchorEl);

  const handleClick = (event) => {
    setAnchorEl(event.currentTarget);
  };

  const handleClose = () => {
    setAnchorEl(null);
  };

  const handleStandardSelect = (newStandard) => {
    setTokenStandard(newStandard);
    handleClose();
  };

  const displayLabel = tokenStandard === 'ERC721' ? 'ERC-721 + ERC-20' : 'ERC-1155';

  return (
    <Box>
      <Tooltip title={getDescription()} placement="bottom" arrow>
        <Chip
          label={`Standard: ${displayLabel}`}
          variant="outlined"
          onClick={handleClick}
          aria-label="Token Standard"
          data-testid="token-standard-toggle"
          sx={{
            color: 'white',
            borderColor: 'rgba(255, 255, 255, 0.3)',
            backgroundColor: 'rgba(255, 255, 255, 0.1)',
            '&:hover': {
              backgroundColor: 'rgba(255, 255, 255, 0.2)',
              borderColor: 'rgba(255, 255, 255, 0.5)',
            },
            cursor: 'pointer',
            fontSize: '0.8rem',
            fontWeight: 'medium',
          }}
        />
      </Tooltip>

      <Menu
        anchorEl={anchorEl}
        open={open}
        onClose={handleClose}
        anchorOrigin={{
          vertical: 'bottom',
          horizontal: 'center',
        }}
        transformOrigin={{
          vertical: 'top',
          horizontal: 'center',
        }}
        PaperProps={{
          sx: {
            minWidth: 250,
            mt: 1,
          },
        }}
      >
        <MenuItem
          onClick={() => handleStandardSelect('ERC721')}
          selected={tokenStandard === 'ERC721'}
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-start',
            py: 1.5,
            gap: 0.5,
          }}
        >
          <Box sx={{ fontWeight: 'bold', fontSize: '0.9rem' }}>
            ERC-721 + ERC-20
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.secondary' }}>
            Separate contracts for property NFTs and yield tokens
          </Box>
        </MenuItem>
        <MenuItem
          onClick={() => handleStandardSelect('ERC1155')}
          selected={tokenStandard === 'ERC1155'}
          sx={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-start',
            py: 1.5,
            gap: 0.5,
          }}
        >
          <Box sx={{ fontWeight: 'bold', fontSize: '0.9rem' }}>
            ERC-1155
          </Box>
          <Box sx={{ fontSize: '0.8rem', color: 'text.secondary' }}>
            Single contract for both property and yield tokens
          </Box>
        </MenuItem>
      </Menu>
    </Box>
  );
}

export default TokenStandardToggle;
