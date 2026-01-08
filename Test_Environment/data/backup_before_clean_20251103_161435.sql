--
-- PostgreSQL database dump
--

\restrict ujEBSVmLIaf21qtgJPd8mFj2ZS51RUv9vW6JwYO7mIlvdhahdWVb5B0cBQMEbdR

-- Dumped from database version 15.14
-- Dumped by pg_dump version 15.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: transactionstatus; Type: TYPE; Schema: public; Owner: rwa_test_user
--

CREATE TYPE public.transactionstatus AS ENUM (
    'PENDING',
    'CONFIRMED',
    'FAILED'
);


ALTER TYPE public.transactionstatus OWNER TO rwa_test_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: properties; Type: TABLE; Schema: public; Owner: rwa_test_user
--

CREATE TABLE public.properties (
    id integer NOT NULL,
    property_address_hash bytea NOT NULL,
    metadata_uri character varying,
    metadata_json character varying,
    rental_agreement_uri character varying,
    verification_timestamp timestamp without time zone,
    is_verified boolean,
    verifier_address character varying(42),
    blockchain_token_id integer,
    token_standard character varying(10) DEFAULT 'ERC721'::character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.properties OWNER TO rwa_test_user;

--
-- Name: COLUMN properties.property_address_hash; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.property_address_hash IS 'Keccak256 hash of property address (bytes32)';


--
-- Name: COLUMN properties.metadata_uri; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.metadata_uri IS 'IPFS CID containing property metadata JSON (optional)';


--
-- Name: COLUMN properties.metadata_json; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.metadata_json IS 'JSON string containing property metadata';


--
-- Name: COLUMN properties.rental_agreement_uri; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.rental_agreement_uri IS 'IPFS URI containing rental agreement document';


--
-- Name: COLUMN properties.verification_timestamp; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.verification_timestamp IS 'Timestamp when property was verified by authorized verifier';


--
-- Name: COLUMN properties.is_verified; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.is_verified IS 'Whether property has been verified by authorized party';


--
-- Name: COLUMN properties.verifier_address; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.verifier_address IS 'Ethereum address of the verifier (0x-prefixed)';


--
-- Name: COLUMN properties.blockchain_token_id; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.blockchain_token_id IS 'Token ID from PropertyNFT or CombinedPropertyYieldToken contract';


--
-- Name: COLUMN properties.token_standard; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.token_standard IS 'Token standard used: ''ERC721'' or ''ERC1155''';


--
-- Name: COLUMN properties.created_at; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.created_at IS 'Record creation timestamp';


--
-- Name: COLUMN properties.updated_at; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.properties.updated_at IS 'Last update timestamp';


--
-- Name: properties_id_seq; Type: SEQUENCE; Schema: public; Owner: rwa_test_user
--

CREATE SEQUENCE public.properties_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.properties_id_seq OWNER TO rwa_test_user;

--
-- Name: properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rwa_test_user
--

ALTER SEQUENCE public.properties_id_seq OWNED BY public.properties.id;


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: rwa_test_user
--

CREATE TABLE public.transactions (
    id integer NOT NULL,
    tx_hash character varying(66) NOT NULL,
    block_number integer,
    "timestamp" timestamp without time zone,
    status public.transactionstatus,
    gas_used integer,
    contract_address character varying(42) NOT NULL,
    function_name character varying(100) NOT NULL,
    yield_agreement_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.transactions OWNER TO rwa_test_user;

--
-- Name: COLUMN transactions.tx_hash; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.tx_hash IS 'Ethereum transaction hash (0x-prefixed, 66 characters)';


--
-- Name: COLUMN transactions.block_number; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.block_number IS 'Block number where transaction was mined';


--
-- Name: COLUMN transactions."timestamp"; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions."timestamp" IS 'Timestamp when transaction was processed';


--
-- Name: COLUMN transactions.status; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.status IS 'Current status of the transaction';


--
-- Name: COLUMN transactions.gas_used; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.gas_used IS 'Gas units consumed by transaction';


--
-- Name: COLUMN transactions.contract_address; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.contract_address IS 'Target contract address (0x-prefixed)';


--
-- Name: COLUMN transactions.function_name; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.function_name IS 'Smart contract function called';


--
-- Name: COLUMN transactions.yield_agreement_id; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.yield_agreement_id IS 'Associated yield agreement if applicable';


--
-- Name: COLUMN transactions.created_at; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.created_at IS 'Record creation timestamp';


--
-- Name: COLUMN transactions.updated_at; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.transactions.updated_at IS 'Last update timestamp';


--
-- Name: transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: rwa_test_user
--

CREATE SEQUENCE public.transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transactions_id_seq OWNER TO rwa_test_user;

--
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rwa_test_user
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- Name: validation_records; Type: TABLE; Schema: public; Owner: rwa_test_user
--

CREATE TABLE public.validation_records (
    id integer NOT NULL,
    property_id integer NOT NULL,
    deed_hash character varying(66) NOT NULL,
    rental_agreement_uri character varying(1000) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.validation_records OWNER TO rwa_test_user;

--
-- Name: validation_records_id_seq; Type: SEQUENCE; Schema: public; Owner: rwa_test_user
--

CREATE SEQUENCE public.validation_records_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.validation_records_id_seq OWNER TO rwa_test_user;

--
-- Name: validation_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rwa_test_user
--

ALTER SEQUENCE public.validation_records_id_seq OWNED BY public.validation_records.id;


--
-- Name: yield_agreements; Type: TABLE; Schema: public; Owner: rwa_test_user
--

CREATE TABLE public.yield_agreements (
    id integer NOT NULL,
    property_id integer NOT NULL,
    upfront_capital numeric(78,0) NOT NULL,
    upfront_capital_usd numeric(18,2) NOT NULL,
    monthly_payment_usd numeric(18,2) NOT NULL,
    repayment_term_months integer NOT NULL,
    annual_roi_basis_points integer NOT NULL,
    total_repaid numeric(78,0),
    last_repayment_timestamp timestamp without time zone,
    is_active boolean,
    blockchain_agreement_id integer,
    token_standard character varying(10) NOT NULL,
    token_contract_address character varying(42),
    grace_period_days integer NOT NULL,
    default_penalty_rate integer NOT NULL,
    allow_partial_repayments boolean,
    allow_early_repayment boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.yield_agreements OWNER TO rwa_test_user;

--
-- Name: COLUMN yield_agreements.property_id; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.property_id IS 'Reference to associated property';


--
-- Name: COLUMN yield_agreements.upfront_capital; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.upfront_capital IS 'Initial capital invested in agreement (wei units)';


--
-- Name: COLUMN yield_agreements.upfront_capital_usd; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.upfront_capital_usd IS 'Initial capital invested in agreement (USD)';


--
-- Name: COLUMN yield_agreements.monthly_payment_usd; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.monthly_payment_usd IS 'Monthly payment amount (USD)';


--
-- Name: COLUMN yield_agreements.repayment_term_months; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.repayment_term_months IS 'Total term of the agreement in months';


--
-- Name: COLUMN yield_agreements.annual_roi_basis_points; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.annual_roi_basis_points IS 'Annual return on investment in basis points (1/100th of 1%)';


--
-- Name: COLUMN yield_agreements.total_repaid; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.total_repaid IS 'Total amount repaid so far (wei units)';


--
-- Name: COLUMN yield_agreements.last_repayment_timestamp; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.last_repayment_timestamp IS 'Timestamp of last repayment transaction';


--
-- Name: COLUMN yield_agreements.is_active; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.is_active IS 'Whether the agreement is currently active';


--
-- Name: COLUMN yield_agreements.blockchain_agreement_id; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.blockchain_agreement_id IS 'Agreement ID from YieldBase contract';


--
-- Name: COLUMN yield_agreements.token_standard; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.token_standard IS 'Token standard used: ''ERC721'' or ''ERC1155''';


--
-- Name: COLUMN yield_agreements.token_contract_address; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.token_contract_address IS 'Address of YieldSharesToken or CombinedPropertyYieldToken contract';


--
-- Name: COLUMN yield_agreements.grace_period_days; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.grace_period_days IS 'Grace period in days before default penalties apply';


--
-- Name: COLUMN yield_agreements.default_penalty_rate; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.default_penalty_rate IS 'Penalty rate for late payments (basis points)';


--
-- Name: COLUMN yield_agreements.allow_partial_repayments; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.allow_partial_repayments IS 'Whether partial repayments are allowed';


--
-- Name: COLUMN yield_agreements.allow_early_repayment; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.allow_early_repayment IS 'Whether early repayment is allowed';


--
-- Name: COLUMN yield_agreements.created_at; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.created_at IS 'Agreement creation timestamp';


--
-- Name: COLUMN yield_agreements.updated_at; Type: COMMENT; Schema: public; Owner: rwa_test_user
--

COMMENT ON COLUMN public.yield_agreements.updated_at IS 'Last update timestamp';


--
-- Name: yield_agreements_id_seq; Type: SEQUENCE; Schema: public; Owner: rwa_test_user
--

CREATE SEQUENCE public.yield_agreements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.yield_agreements_id_seq OWNER TO rwa_test_user;

--
-- Name: yield_agreements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: rwa_test_user
--

ALTER SEQUENCE public.yield_agreements_id_seq OWNED BY public.yield_agreements.id;


--
-- Name: properties id; Type: DEFAULT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.properties ALTER COLUMN id SET DEFAULT nextval('public.properties_id_seq'::regclass);


--
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- Name: validation_records id; Type: DEFAULT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.validation_records ALTER COLUMN id SET DEFAULT nextval('public.validation_records_id_seq'::regclass);


--
-- Name: yield_agreements id; Type: DEFAULT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.yield_agreements ALTER COLUMN id SET DEFAULT nextval('public.yield_agreements_id_seq'::regclass);


--
-- Data for Name: properties; Type: TABLE DATA; Schema: public; Owner: rwa_test_user
--

COPY public.properties (id, property_address_hash, metadata_uri, metadata_json, rental_agreement_uri, verification_timestamp, is_verified, verifier_address, blockchain_token_id, token_standard, created_at, updated_at) FROM stdin;
1	\\xc28bc225467d3b7c5f74e6789a5d1252f0d0af3573b30191522dc925abc97ae7	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-10-20 04:57:33.611396	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	1	ERC721	2025-10-20 04:57:32.9303	2025-10-20 04:57:32.9303
2	\\x98cbf8ffc6d3a43dd0340f808e72e41fe202ad7f05100c7daa4bcd886e887681	\N	{"property_type": "residential", "square_footage": 1200, "bedrooms": 3, "year_built": 1990}	https://ipfs.io/ipfs/ze4ycfego	2025-10-20 04:58:48.284614	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	1	ERC1155	2025-10-20 04:58:48.068281	2025-10-20 04:58:48.068281
57	\\x375610f68a4ba7eccc46f263771a462bbe1ada305970c2654ca42b31a12ba2bb	\N	{"property_type": "residential", "square_footage": 1200, "bedrooms": 3, "year_built": 1990}	https://ipfs.io/ipfs/bt2dicj42	2025-10-20 06:18:48.161489	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	3	ERC1155	2025-10-20 06:18:47.793781	2025-10-20 06:18:47.793781
6	\\xb5fe54d71c0450e306adc4468954f5e9741f28e4df4ac45da9a1f04d75c97082	\N	{"property_type": "residential", "square_footage": 1200, "bedrooms": 3, "year_built": 1990}	https://ipfs.io/ipfs/j2aj1jqbh	2025-10-20 05:06:05.829422	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	2	ERC1155	2025-10-20 05:06:05.423472	2025-10-20 05:06:05.423472
64	\\x2341e85aa14a18d6f61470e05aa4b04983f02684450b6717ed4f1815a55af275	\N	{"property_type": "residential", "square_footage": 1200, "bedrooms": 3, "year_built": 1990}	https://ipfs.io/ipfs/lp815633w	2025-10-20 06:29:01.845082	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	4	ERC1155	2025-10-20 06:29:01.380793	2025-10-20 06:29:01.380793
539	\\x9b47e08078d7c89656ac1a9d182b2a7e11b87e726b865a7b8c690792a30873eb	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:46:23.762384	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	1	ERC721	2025-11-03 11:46:23.610523	2025-11-03 11:46:23.610523
540	\\x4a3187935f14d0fc766f5f8672edaedf068138c2a6067c90857b4fdd7fe713ab	\N	{"property_type": "residential", "square_footage": 1200, "bedrooms": 3, "year_built": 1990}	https://ipfs.io/ipfs/suca0pl1s	2025-11-03 11:46:38.040816	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	2	ERC721	2025-11-03 11:46:37.979459	2025-11-03 11:46:37.979459
541	\\x1932e70d4681107a8be181474e6025f4ef9d4542ed5028c4bfa7c9dd04f8dfab	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:47:47.597428	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	3	ERC721	2025-11-03 11:47:47.431466	2025-11-03 11:47:47.431466
542	\\x1a8e8d2a655a012dd4e32d7e82deee63a614ffe0d8d48c423f6ca91583a11bd8	\N	{"property_type": "commercial", "square_footage": 5004, "bedrooms": 0, "year_built": 2000}	https://ipfs.io/ipfs/v51kl8yq7	2025-11-03 11:48:32.959623	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	4	ERC721	2025-11-03 11:48:32.861869	2025-11-03 11:48:32.861869
543	\\xa0e78128397a47953eb62f65446aa7720f1a04683ab10b57a9517cd3a381666b	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:49:04.915344	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	5	ERC721	2025-11-03 11:49:04.793154	2025-11-03 11:49:04.793154
31	\\xc9635db13278dd1608ccd8350098e68d22de0ccd5eeac19a6e8e028ca35efd8f	\N	{"property_type": "residential", "square_footage": 1200, "bedrooms": 3, "year_built": 1990}	https://ipfs.io/ipfs/btow6mhce	2025-10-20 05:42:31.205705	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	3	ERC1155	2025-10-20 05:42:30.239209	2025-10-20 05:42:30.239209
544	\\xe65264758d9894801c4dab80fb956a0db03ec782bd82f30baac991acd795995f	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:50:21.064516	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	6	ERC721	2025-11-03 11:50:21.017042	2025-11-03 11:50:21.017042
545	\\x2fa44e043662c2cb6defb0d3dc16fbb9ee6f0b9fd1815396ea11f744eb2d1542	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:51:48.354284	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	7	ERC721	2025-11-03 11:51:48.083112	2025-11-03 11:51:48.083112
546	\\x345899622c0a003dd9277a0d908b7f839f8c105dd26ddd8f1d4418a2f6ff513d	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:53:08.196259	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	8	ERC721	2025-11-03 11:53:08.150226	2025-11-03 11:53:08.150226
547	\\x68dc1de66d0944bef2c178cab47f7cb00d1c25ba42fef8abdb385b0120a63a7e	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:54:25.847184	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	9	ERC721	2025-11-03 11:54:25.701869	2025-11-03 11:54:25.701869
41	\\x2da24b6417c8afc2a25d3aa4bb8b71cc6bfc09198bcc25ec58794a8605a91b66	\N	{"property_type": "residential", "square_footage": 1200, "bedrooms": 3, "year_built": 1990}	https://ipfs.io/ipfs/btow6mhce	2025-10-20 05:56:25.949359	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	1	ERC1155	2025-10-20 05:56:25.0525	2025-10-20 05:56:25.0525
548	\\x00003be40dc5ae9437dea711d70fd152fc47d50de20680675fbf4db5fafc12bb	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:55:42.716461	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	10	ERC721	2025-11-03 11:55:42.630348	2025-11-03 11:55:42.630348
44	\\xf1830a0f3f92e01c416bc4d9378d59219bb48abdbce603ad9ff98778e05a0ad4	\N	{"property_type": "residential", "square_footage": 1200, "bedrooms": 3, "year_built": 1990}	https://ipfs.io/ipfs/3epeho7g6	2025-10-20 05:59:08.273222	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	2	ERC1155	2025-10-20 05:59:07.336872	2025-10-20 05:59:07.336872
549	\\xfa3c73c22d25622f42afd368d3ffdb92f2d01de6b62f1a8206d5eab19e01e9e5	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:56:59.965336	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	11	ERC721	2025-11-03 11:56:59.935542	2025-11-03 11:56:59.935542
550	\\x7acb8fdd1c62a3b25a3f7eda8dbf20b5218fa7f00e6e880dbae88cfeb977b6bb	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:58:16.834463	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	12	ERC721	2025-11-03 11:58:16.753905	2025-11-03 11:58:16.753905
551	\\x7c2380e0151a5a3a1fe274e653ed6ae75c6944e6d77729f7dbd022c2646569bc	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 11:59:28.74854	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	13	ERC721	2025-11-03 11:59:28.717926	2025-11-03 11:59:28.717926
552	\\x7816d1ef99b94c3c7aeedd2a85ef43bd8fa0c1d12a5ffc43e4840bf77e8e2af8	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 12:00:56.319715	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	14	ERC721	2025-11-03 12:00:56.274224	2025-11-03 12:00:56.274224
553	\\xf739f5e7835dc6215966208954b13204ff5b9da3f80609c3a97317a55b6fef47	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 12:02:18.67649	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	15	ERC721	2025-11-03 12:02:18.487028	2025-11-03 12:02:18.487028
554	\\x40fc36ba5210570ba7f429130f6ab4b27b2236dc3d271f57164bf56e2999a580	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 12:04:01.230745	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	16	ERC721	2025-11-03 12:04:01.069033	2025-11-03 12:04:01.069033
555	\\x556d91045ea3781d047182ac072a4a5ff6e09fee97bbb4ab874b2bbfd9684391	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 12:05:23.269077	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	17	ERC721	2025-11-03 12:05:23.117851	2025-11-03 12:05:23.117851
556	\\x69b7017df8923941a396b485ca7a1463073290046e47262bed8b0031c8a4bb82	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 12:06:39.823273	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	18	ERC721	2025-11-03 12:06:39.681319	2025-11-03 12:06:39.681319
557	\\xaf1ed30e79e7c96dd4a5312418593190424055bfc9419a32f529da6b3cfd529b	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 12:07:59.914968	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	19	ERC721	2025-11-03 12:07:59.705278	2025-11-03 12:07:59.705278
558	\\x401355e9f2759056cfd845edf18b85a490e40bc333d68fd1960d0801bd50b01e	\N	{"property_type": "residential", "square_footage": 1200}	https://example.com/rental-agreement.pdf	2025-11-03 12:09:23.044323	t	0x742d35Cc6569C0530fA2A48E9c8c5d5b5b5b5b5	20	ERC721	2025-11-03 12:09:22.685035	2025-11-03 12:09:22.685035
\.


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: rwa_test_user
--

COPY public.transactions (id, tx_hash, block_number, "timestamp", status, gas_used, contract_address, function_name, yield_agreement_id, created_at, updated_at) FROM stdin;
1	0xc9a16febc49f89647454db2cc16478d7db5c852e649e3df9cd067360b1f4f9e1	\N	2025-10-20 04:57:33.633061	CONFIRMED	201175	0x0355B7B8cb128fA5692729Ab3AAa199C1753f726	mintProperty	\N	2025-10-20 04:57:32.9303	2025-10-20 04:57:32.9303
2	0xbfcaa3da4f3250c3df9c56e9a301e8fdb6d8c3494791a271ae3024d2fd87ee34	\N	2025-10-20 04:57:33.7705	CONFIRMED	76988	0x0355B7B8cb128fA5692729Ab3AAa199C1753f726	verifyProperty	\N	2025-10-20 04:57:32.9303	2025-10-20 04:57:32.9303
3	0x33f6241f354acd135b2090d54afcf4363fba5cb928af6871cb17776861da5f7d	\N	2025-10-20 04:58:48.2943	CONFIRMED	223768	0xD84379CEae14AA33C123Af12424A37803F885889	mintPropertyToken	\N	2025-10-20 04:58:48.068281	2025-10-20 04:58:48.068281
4	0x7b96ec5a8a5ac3eee25928d18035aac57de0a3fe632e14dd2a3f85a1fe86b8bb	\N	2025-10-20 04:58:48.310225	CONFIRMED	77117	0x0355B7B8cb128fA5692729Ab3AAa199C1753f726	verifyProperty	\N	2025-10-20 04:58:48.068281	2025-10-20 04:58:48.068281
5	0xfec3b2994cb421798fa4a0021c87d7e16ea7f3c767a37cb570c457245405a48e	\N	2025-10-20 04:59:09.939468	CONFIRMED	346852	0xD84379CEae14AA33C123Af12424A37803F885889	mintYieldTokens	1	2025-10-20 04:59:09.675772	2025-10-20 04:59:09.675772
6	0x8541fe6932722b051654d1f3dbc9b8a0f7b321c71fcaf62e6d80449ef3e173a0	\N	2025-10-20 05:04:15.277479	CONFIRMED	91298	0xD84379CEae14AA33C123Af12424A37803F885889	mintYieldTokens	2	2025-10-20 05:04:15.022674	2025-10-20 05:04:15.022674
7	0x2e7dee77edaf692fdefc23d329f5e954e6ce3de252257969cab44b32ed4be006	\N	2025-10-20 05:06:05.872746	CONFIRMED	206668	0xD84379CEae14AA33C123Af12424A37803F885889	mintPropertyToken	\N	2025-10-20 05:06:05.423472	2025-10-20 05:06:05.423472
8	0x13b5fa8c8e5c3910df58d0c7141b636a087f1ca7f2bf271c88c9ab5cc3ca48e0	\N	2025-10-20 05:06:05.949124	CONFIRMED	77117	0x0355B7B8cb128fA5692729Ab3AAa199C1753f726	verifyProperty	\N	2025-10-20 05:06:05.423472	2025-10-20 05:06:05.423472
9	0x254b8d3fb538f061b4b76f2b727feb959f1aec9dd25f19e0dfec1e38d5f98ab4	\N	2025-10-20 05:11:49.508025	CONFIRMED	346852	0xD84379CEae14AA33C123Af12424A37803F885889	mintYieldTokens	3	2025-10-20 05:11:49.226456	2025-10-20 05:11:49.226456
10	0xc6e15f62bf2ecd8cdfbef2d2bd656a7d2d826e2f4b81d23d036c2f0bb4288256	\N	2025-10-20 05:17:46.237543	CONFIRMED	91298	0xD84379CEae14AA33C123Af12424A37803F885889	mintYieldTokens	4	2025-10-20 05:17:45.819396	2025-10-20 05:17:45.819396
11	0x26ea6601a80266bdb8e9d1721a7cd7c66998fc7bf914b3d69b898a9fec2ea709	\N	2025-10-20 05:42:31.306976	CONFIRMED	206656	0xD84379CEae14AA33C123Af12424A37803F885889	mintPropertyToken	\N	2025-10-20 05:42:30.239209	2025-10-20 05:42:30.239209
12	0x0ea52b873a9a808e1040157d95140084ae13d86f1d11e5cc783872d294cdb28a	\N	2025-10-20 05:42:31.33944	CONFIRMED	77117	0x0355B7B8cb128fA5692729Ab3AAa199C1753f726	verifyProperty	\N	2025-10-20 05:42:30.239209	2025-10-20 05:42:30.239209
13	0x5ac2ee31e919b1771746be8d045055464f94f4b644be5ecc5a16a74a00260ff4	\N	2025-10-20 05:46:26.672245	CONFIRMED	346852	0xD84379CEae14AA33C123Af12424A37803F885889	mintYieldTokens	5	2025-10-20 05:46:26.394773	2025-10-20 05:46:26.394773
14	0xb3cba9a192636c0c646c11dbcf890d20898f44dda67e5538f825a8dde4fdff22	\N	2025-10-20 05:56:25.989803	CONFIRMED	223768	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	mintPropertyToken	\N	2025-10-20 05:56:25.0525	2025-10-20 05:56:25.0525
15	0x72be443f046ef4f615d3274e33c144efdb19b0a8f8404ef73473a281fac47ebe	\N	2025-10-20 05:56:26.010338	CONFIRMED	77117	0xe8D2A1E88c91DCd5433208d4152Cc4F399a7e91d	verifyProperty	\N	2025-10-20 05:56:25.0525	2025-10-20 05:56:25.0525
16	0x57fc980b628693852bd2673c8584f2da7e8b2a98db38840b30120255e5d1b284	\N	2025-10-20 05:56:30.682959	CONFIRMED	346852	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	mintYieldTokens	6	2025-10-20 05:56:30.522454	2025-10-20 05:56:30.522454
17	0xcb329a15cee7ed60731e3e65b0a6a0280739c7989b512a762b94bcb74e5fcec0	\N	2025-10-20 05:59:08.33019	CONFIRMED	206668	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	mintPropertyToken	\N	2025-10-20 05:59:07.336872	2025-10-20 05:59:07.336872
18	0x3d34d1dddb00455fc9a82b14fe62969f14d97cf37e2be64145920dd54c14fe73	\N	2025-10-20 05:59:08.401711	CONFIRMED	77117	0xe8D2A1E88c91DCd5433208d4152Cc4F399a7e91d	verifyProperty	\N	2025-10-20 05:59:07.336872	2025-10-20 05:59:07.336872
19	0x0410a06d2556ea04e139481d260cab854af5512cd3f60fb78392bdffe49f472e	\N	2025-10-20 06:01:36.342261	CONFIRMED	346852	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	mintYieldTokens	7	2025-10-20 06:01:35.986517	2025-10-20 06:01:35.986517
20	0x6a22bc6e1356a217f9e5c73f19dae6070e558409e924eead9dfa4acc2e1705c7	\N	2025-10-20 06:18:48.187397	CONFIRMED	206668	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	mintPropertyToken	\N	2025-10-20 06:18:47.793781	2025-10-20 06:18:47.793781
21	0x2c9cc43ecd837a6bf1ea2097a4980a1ada3c81ed8df0f9e7d79bbb0b39f4137c	\N	2025-10-20 06:18:48.258244	CONFIRMED	77117	0xe8D2A1E88c91DCd5433208d4152Cc4F399a7e91d	verifyProperty	\N	2025-10-20 06:18:47.793781	2025-10-20 06:18:47.793781
22	0x6b5440fb4556c36f4ac40a85ad652f636b1ea1dc9095915b9f4652c5a55876f0	\N	2025-10-20 06:24:46.708236	CONFIRMED	346852	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	mintYieldTokens	8	2025-10-20 06:24:46.392269	2025-10-20 06:24:46.392269
23	0x71a3fd052b30b48d86303355a437d7132cc2f1d7e564020b331b136aed34134f	\N	2025-10-20 06:29:01.873591	CONFIRMED	206668	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	mintPropertyToken	\N	2025-10-20 06:29:01.380793	2025-10-20 06:29:01.380793
24	0x8179ec77569fdace86ac27d8931601cf622ef3ead930744ae3cce8a5df64279f	\N	2025-10-20 06:29:02.090798	CONFIRMED	77117	0xe8D2A1E88c91DCd5433208d4152Cc4F399a7e91d	verifyProperty	\N	2025-10-20 06:29:01.380793	2025-10-20 06:29:01.380793
25	0xc324d8c0af20e53bb94828c78e878f47383d310a97aac72b4791a0bce5737280	\N	2025-11-03 11:46:23.771251	CONFIRMED	201175	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:46:23.610523	2025-11-03 11:46:23.610523
26	0x06d1cc53942f4ccc22b9abfaa84c32e363a0fa7b319dd0885e071dc41d10067d	\N	2025-11-03 11:46:23.791716	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:46:23.610523	2025-11-03 11:46:23.610523
27	0x003ee6fd89b6de85dd75af679368713c253b986bdd48a903d8d8656782bb5de0	\N	2025-11-03 11:46:38.042381	CONFIRMED	121957	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:46:37.979459	2025-11-03 11:46:37.979459
28	0x409d37cf051ca530d7ee3750fa5ce95e2673608b4a3a7a66084c9030f9411d00	\N	2025-11-03 11:46:38.097168	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:46:37.979459	2025-11-03 11:46:37.979459
29	0x1661ef1c0a92a23632317a6672b1f33be16ea9b29a111d566e1030e74bcc49b2	\N	2025-11-03 11:46:59.83023	CONFIRMED	3221527	0x9A676e781A523b5d0C0e43731313A708CB607508	createYieldAgreement	9	2025-11-03 11:46:59.691077	2025-11-03 11:46:59.691077
30	0x76a79650b8148f64041cb3ebc802725b71166fc2a7b4ac47e1177abccb2b2ed0	\N	2025-11-03 11:47:47.601697	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:47:47.431466	2025-11-03 11:47:47.431466
31	0x2af81c7ed25084631ec545ed3bcc71656a2c3fa1002066bcbf6a2e7b08e98a0a	\N	2025-11-03 11:47:47.654903	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:47:47.431466	2025-11-03 11:47:47.431466
32	0x2d0755911e21cc036af0b9856c6f76d1d171631ed81555a9f314d5e7b4a9a39c	\N	2025-11-03 11:48:32.962738	CONFIRMED	121957	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:48:32.861869	2025-11-03 11:48:32.861869
33	0x9007204fac3b4e51ef38246dbd2ee8d71c9a8c1967caf1d0e084edc86593f803	\N	2025-11-03 11:48:32.975217	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:48:32.861869	2025-11-03 11:48:32.861869
34	0xf79c676106393115fa55a5e17254ea522404153fad78772486e81ea47c27a925	\N	2025-11-03 11:48:54.492956	CONFIRMED	3221539	0x9A676e781A523b5d0C0e43731313A708CB607508	createYieldAgreement	10	2025-11-03 11:48:54.396193	2025-11-03 11:48:54.396193
35	0x408c4ef8458b316b6d5ee9e9e88ec79c1cd9ea8ce457f3b6f194100f134a4c7d	\N	2025-11-03 11:49:04.917467	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:49:04.793154	2025-11-03 11:49:04.793154
36	0xc1cbc9e429390e07c722deb279ae39c4e1a353a700fe8764fec5292ee2dd7fac	\N	2025-11-03 11:49:04.927428	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:49:04.793154	2025-11-03 11:49:04.793154
37	0x0d979a4b2c700ae8965a3d28e9cd1a5417326229ee5ca4f6ecc5356962a9657f	\N	2025-11-03 11:50:21.068625	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:50:21.017042	2025-11-03 11:50:21.017042
38	0xf98f48d2c22e84a1d405429864a28bc56d83173d6565719f4503905e4a05e173	\N	2025-11-03 11:50:21.126832	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:50:21.017042	2025-11-03 11:50:21.017042
39	0x931dc0d2654535efc63503377dd70825a1265c48bf0349e9861178e0a74d2495	\N	2025-11-03 11:51:48.365661	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:51:48.083112	2025-11-03 11:51:48.083112
40	0x7993fb6ad1d07fb3f5cfc7fe19bbf5c39e4a24c331ec04960c5021ebdfccf5ba	\N	2025-11-03 11:51:48.817778	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:51:48.083112	2025-11-03 11:51:48.083112
41	0x096ada30ebd16822fdd545f79c546017e10fabf15ec717c7e1bed9f5e4390dd3	\N	2025-11-03 11:53:08.199502	CONFIRMED	166963	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:53:08.150226	2025-11-03 11:53:08.150226
42	0xc639adc2a4b42ad14b09d40fa16157442bd179ea86169405529a31699a3fa3b5	\N	2025-11-03 11:53:08.211573	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:53:08.150226	2025-11-03 11:53:08.150226
43	0x3be524e3a221e84487c0678027d148a8f8dcb2cb44321768e46be7887ba1884a	\N	2025-11-03 11:54:25.850082	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:54:25.701869	2025-11-03 11:54:25.701869
44	0x636a055fc8f018c4736c3250c564a78c0a9248c4a2d1bce2ae53814436777806	\N	2025-11-03 11:54:25.860713	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:54:25.701869	2025-11-03 11:54:25.701869
45	0xc74639bc5a46f862af3951ccd85b01541aa6c7306c917b39ed6b3b9d064a9acd	\N	2025-11-03 11:55:42.718108	CONFIRMED	166951	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:55:42.630348	2025-11-03 11:55:42.630348
46	0x66f58144c1468311de3897ef21289345a9669d65d7edd8433bbb9722fcb554aa	\N	2025-11-03 11:55:42.775559	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:55:42.630348	2025-11-03 11:55:42.630348
47	0x5796f382ff54c67731cd7795108982c2dfc37cef760b2c18f857336efe1be2d8	\N	2025-11-03 11:56:59.968721	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:56:59.935542	2025-11-03 11:56:59.935542
48	0x36a63e898c17219f239019f3f316197a68ae6f4582603a2f23f8c9ec27281f53	\N	2025-11-03 11:56:59.981957	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:56:59.935542	2025-11-03 11:56:59.935542
49	0x0ed42e08caf5ad26fc2f2c9f5fe089704a808d2316f84bb679ba199ae4eaba9f	\N	2025-11-03 11:58:16.837187	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:58:16.753905	2025-11-03 11:58:16.753905
50	0x45ee538e07ca10e06d368929703550f933b78654c28d9af870fcc84096fb620f	\N	2025-11-03 11:58:16.852478	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:58:16.753905	2025-11-03 11:58:16.753905
51	0x081de8ab8fbb9993d47c3b8773f819c67350f588efa7698f4f5b84bb2f42de01	\N	2025-11-03 11:59:28.750773	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 11:59:28.717926	2025-11-03 11:59:28.717926
52	0xf3a79c8d48cb3984145f08b1fd026e60c55943be08f98601b672f3f331c3836c	\N	2025-11-03 11:59:28.761438	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 11:59:28.717926	2025-11-03 11:59:28.717926
53	0x7c96a30d4aa79e6d6f9e9c47d8ad83ebac7a6ed9a37a0563e205cfcbffa2e1b2	\N	2025-11-03 12:00:56.321918	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 12:00:56.274224	2025-11-03 12:00:56.274224
54	0xf34152104d50347d1eac7638331116231732cd589f9276c70c7be80734cff609	\N	2025-11-03 12:00:56.331856	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 12:00:56.274224	2025-11-03 12:00:56.274224
55	0x0e8eb0c8d2d8ae2619f61f40db9eab6a4664b6f75a7f0a50abe85d67d93cbbe8	\N	2025-11-03 12:02:18.691109	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 12:02:18.487028	2025-11-03 12:02:18.487028
56	0x65db82a25a8b35a3d80c946aaa0306e1ba4a6677aaa335d0ee58eae903cdb630	\N	2025-11-03 12:02:18.750096	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 12:02:18.487028	2025-11-03 12:02:18.487028
57	0x670950fde890e117997c58cde03d7ab6fbd7f96a837469f494ccf3c0f52c62ff	\N	2025-11-03 12:04:01.233165	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 12:04:01.069033	2025-11-03 12:04:01.069033
58	0xb82030bcf5e63dfeebdfb07b13d0122e71517befc55690cc67cf1757342df499	\N	2025-11-03 12:04:01.244905	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 12:04:01.069033	2025-11-03 12:04:01.069033
59	0x9a7b7e147279b92f6c09ddb1bdfae32818c1c09eb5d752ac7840446660eb908e	\N	2025-11-03 12:05:23.271338	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 12:05:23.117851	2025-11-03 12:05:23.117851
60	0xc902fa14a54b059b36816354f1c380cbc95f16076188071240ec86a3dccb9a2a	\N	2025-11-03 12:05:23.280145	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 12:05:23.117851	2025-11-03 12:05:23.117851
61	0x6038b23a0bb00df71f0060f5ef97a2201d4e2f1da676a33a85f411050c154bdf	\N	2025-11-03 12:06:39.824758	CONFIRMED	166963	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 12:06:39.681319	2025-11-03 12:06:39.681319
62	0x0a92b5a82904144aac4b6a9134eb4c6d3da441e85f7ca0aeb93128aea5e84b4f	\N	2025-11-03 12:06:39.834556	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 12:06:39.681319	2025-11-03 12:06:39.681319
63	0x3660ebdabcf21ccb5bf6656fe2a75c4c6d59d3e8c416234af36751895e17bded	\N	2025-11-03 12:07:59.923549	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 12:07:59.705278	2025-11-03 12:07:59.705278
64	0x2e682ce7a448dd8f2983c76ac4030c35b0905bf081dc30a7ea0082c7f75b844a	\N	2025-11-03 12:08:00.025406	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 12:07:59.705278	2025-11-03 12:07:59.705278
65	0x3037f275f8410ed492b41c82b92f53acabbe43b73ee1d133801fcadd65b5fa6b	\N	2025-11-03 12:09:23.049959	CONFIRMED	166975	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	mintProperty	\N	2025-11-03 12:09:22.685035	2025-11-03 12:09:22.685035
66	0x7b14f3c149ec6f349cdf59ebe3f75e74626482a80f6bc869f000c3178513861b	\N	2025-11-03 12:09:23.152692	CONFIRMED	76988	0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0	verifyProperty	\N	2025-11-03 12:09:22.685035	2025-11-03 12:09:22.685035
\.


--
-- Data for Name: validation_records; Type: TABLE DATA; Schema: public; Owner: rwa_test_user
--

COPY public.validation_records (id, property_id, deed_hash, rental_agreement_uri, created_at) FROM stdin;
1	1	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-10-20 04:57:32.9303+00
2	2	0xd112df13c257a2748f67f7b7b1513ef2a938a91edaaa565abf2ae29cfc4f1daa	https://ipfs.io/ipfs/ze4ycfego	2025-10-20 04:58:48.068281+00
3	6	0x9a7bd665454dedd21097e9372b713b423234152b3ba4cc9a9605a902a0cedbc6	https://ipfs.io/ipfs/j2aj1jqbh	2025-10-20 05:06:05.423472+00
4	31	0x9a5461cbe966f6730657fe2341ca9827556776befd8cb1cb0f2eca712ce0042a	https://ipfs.io/ipfs/btow6mhce	2025-10-20 05:42:30.239209+00
5	41	0x9a7bd665454dedd21097e9372b713b423234152b3ba4cc9a9605a902a0cedbc6	https://ipfs.io/ipfs/btow6mhce	2025-10-20 05:56:25.0525+00
6	44	0x30771238bc47caa0176df0e54828d2e701aa8bf444c9a918bd165806294fc778	https://ipfs.io/ipfs/3epeho7g6	2025-10-20 05:59:07.336872+00
7	57	0x031a8fb20df2074cd7b98242f061de4b23fc3c7a05373eec5d6edf102f97430c	https://ipfs.io/ipfs/bt2dicj42	2025-10-20 06:18:47.793781+00
8	64	0xddcc27bb47b7d70cce1f83f38f4a5ffcc396a1bfb2e29301efdc9aeb961d130b	https://ipfs.io/ipfs/lp815633w	2025-10-20 06:29:01.380793+00
9	539	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:46:23.610523+00
10	540	0xa1ed4f1ea38a10be9c9c6aa46404026c09e905881524ff9090326b5a9ba96e8c	https://ipfs.io/ipfs/suca0pl1s	2025-11-03 11:46:37.979459+00
11	541	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:47:47.431466+00
12	542	0xb8effdb9d5964def12155418a2f492ec83306f78cbfd82d478e386783eb92493	https://ipfs.io/ipfs/v51kl8yq7	2025-11-03 11:48:32.861869+00
13	543	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:49:04.793154+00
14	544	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:50:21.017042+00
15	545	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:51:48.083112+00
16	546	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:53:08.150226+00
17	547	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:54:25.701869+00
18	548	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:55:42.630348+00
19	549	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:56:59.935542+00
20	550	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:58:16.753905+00
21	551	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 11:59:28.717926+00
22	552	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 12:00:56.274224+00
23	553	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 12:02:18.487028+00
24	554	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 12:04:01.069033+00
25	555	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 12:05:23.117851+00
26	556	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 12:06:39.681319+00
27	557	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 12:07:59.705278+00
28	558	0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef	https://example.com/rental-agreement.pdf	2025-11-03 12:09:22.685035+00
\.


--
-- Data for Name: yield_agreements; Type: TABLE DATA; Schema: public; Owner: rwa_test_user
--

COPY public.yield_agreements (id, property_id, upfront_capital, upfront_capital_usd, monthly_payment_usd, repayment_term_months, annual_roi_basis_points, total_repaid, last_repayment_timestamp, is_active, blockchain_agreement_id, token_standard, token_contract_address, grace_period_days, default_penalty_rate, allow_partial_repayments, allow_early_repayment, created_at, updated_at) FROM stdin;
1	1	2471002782349133000	10000.00	916.67	12	1000	0	\N	t	1000001	ERC1155	0xD84379CEae14AA33C123Af12424A37803F885889	30	2	t	t	2025-10-20 04:59:09.675772	2025-10-20 04:59:09.675772
2	1	2471002782349133000	10000.00	83.33	12	1000	0	\N	t	1000001	ERC1155	0xD84379CEae14AA33C123Af12424A37803F885889	30	2	t	t	2025-10-20 05:04:15.022674	2025-10-20 05:04:15.022674
3	6	2467521251526778600	10000.00	84.17	12	1010	0	\N	t	2000001	ERC1155	0xD84379CEae14AA33C123Af12424A37803F885889	30	2	t	t	2025-10-20 05:11:49.226456	2025-10-20 05:11:49.226456
4	1	2471002782349133000	10000.00	83.33	12	1000	0	\N	t	1000001	ERC1155	0xD84379CEae14AA33C123Af12424A37803F885889	30	2	t	t	2025-10-20 05:17:45.819396	2025-10-20 05:17:45.819396
5	31	2463387897375260300	10000.00	83.50	12	1002	0	\N	t	3000001	ERC1155	0xD84379CEae14AA33C123Af12424A37803F885889	30	2	t	t	2025-10-20 05:46:26.394773	2025-10-20 05:46:26.394773
6	1	2471002782349133000	10000.00	916.83	12	1002	0	\N	t	1000001	ERC1155	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	30	2	t	t	2025-10-20 05:56:30.522454	2025-10-20 05:56:30.522454
7	6	2462702372567466000	10000.00	917.50	12	1010	0	\N	t	2000001	ERC1155	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	30	2	t	t	2025-10-20 06:01:35.986517	2025-10-20 06:01:35.986517
8	57	2451965986327837600	10000.00	917.42	12	1009	0	\N	t	3000001	ERC1155	0xF8e31cb472bc70500f08Cd84917E5A1912Ec8397	30	2	t	t	2025-10-20 06:24:46.392269	2025-10-20 06:24:46.392269
9	6	2694371995775225000	10000.00	875.00	12	500	0	\N	t	1	ERC721	0x06cd7788D77332cF1156f1E327eBC090B5FF16a3	30	2	t	t	2025-11-03 11:46:59.691077	2025-11-03 11:46:59.691077
10	64	26922538472307476000	100000.00	8750.00	12	500	0	\N	t	2	ERC721	0x400890FeB77E0e555D02f8969CA00850f65B96D2	30	2	t	t	2025-11-03 11:48:54.396193	2025-11-03 11:48:54.396193
\.


--
-- Name: properties_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rwa_test_user
--

SELECT pg_catalog.setval('public.properties_id_seq', 560, true);


--
-- Name: transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rwa_test_user
--

SELECT pg_catalog.setval('public.transactions_id_seq', 66, true);


--
-- Name: validation_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rwa_test_user
--

SELECT pg_catalog.setval('public.validation_records_id_seq', 28, true);


--
-- Name: yield_agreements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: rwa_test_user
--

SELECT pg_catalog.setval('public.yield_agreements_id_seq', 10, true);


--
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (id);


--
-- Name: properties properties_property_address_hash_key; Type: CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_property_address_hash_key UNIQUE (property_address_hash);


--
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- Name: transactions transactions_tx_hash_key; Type: CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_tx_hash_key UNIQUE (tx_hash);


--
-- Name: validation_records validation_records_pkey; Type: CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.validation_records
    ADD CONSTRAINT validation_records_pkey PRIMARY KEY (id);


--
-- Name: yield_agreements yield_agreements_pkey; Type: CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.yield_agreements
    ADD CONSTRAINT yield_agreements_pkey PRIMARY KEY (id);


--
-- Name: ix_validation_records_id; Type: INDEX; Schema: public; Owner: rwa_test_user
--

CREATE INDEX ix_validation_records_id ON public.validation_records USING btree (id);


--
-- Name: ix_validation_records_property_id; Type: INDEX; Schema: public; Owner: rwa_test_user
--

CREATE INDEX ix_validation_records_property_id ON public.validation_records USING btree (property_id);


--
-- Name: transactions transactions_yield_agreement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_yield_agreement_id_fkey FOREIGN KEY (yield_agreement_id) REFERENCES public.yield_agreements(id);


--
-- Name: validation_records validation_records_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.validation_records
    ADD CONSTRAINT validation_records_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(id);


--
-- Name: yield_agreements yield_agreements_property_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: rwa_test_user
--

ALTER TABLE ONLY public.yield_agreements
    ADD CONSTRAINT yield_agreements_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(id);


--
-- PostgreSQL database dump complete
--

\unrestrict ujEBSVmLIaf21qtgJPd8mFj2ZS51RUv9vW6JwYO7mIlvdhahdWVb5B0cBQMEbdR

