// Vitest test suite for PropertyRegistrationForm component

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import PropertyRegistrationForm from '../components/PropertyRegistrationForm';
import { TokenStandardProvider } from '../context/TokenStandardContext';
import { PriceProvider } from '../context/PriceContext';
import { BrowserRouter } from 'react-router-dom';
import * as apiClient from '../services/apiClient';

// Mock ToastProvider for testing
const MockToastProvider = ({ children }) => {
  const showToast = vi.fn();
  return (
    <div data-testid="toast-provider">
      {children}
    </div>
  );
};

vi.mock('../App', () => ({
  useToast: () => ({ showToast: vi.fn() }),
}));

// Mock PriceContext
vi.mock('../context/PriceContext', () => ({
  PriceProvider: ({ children }) => <div data-testid="price-provider">{children}</div>,
  useEthPrice: () => ({
    ethUsdPrice: 2000,
    loading: false,
    error: null,
    isUsingFallback: false,
  }),
}));

// Mock apiClient
vi.mock('../services/apiClient', () => ({
  registerProperty: vi.fn(),
}));

// Mock useNavigate
const mockNavigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

// Helper function to render with providers
function renderWithProviders(component) {
  return render(
    <TokenStandardProvider>
      <PriceProvider>
        <BrowserRouter>
          <MockToastProvider>
            {component}
          </MockToastProvider>
        </BrowserRouter>
      </PriceProvider>
    </TokenStandardProvider>
  );
}

describe('PropertyRegistrationForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders form with all required fields', () => {
    renderWithProviders(<PropertyRegistrationForm />);

    expect(screen.getByLabelText(/property address/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/property deed hash \(manual entry\)/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/rental agreement uri \(manual entry\)/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/raw metadata \(json\)/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /register property/i })).toBeInTheDocument();
  });

  it('validates deed hash format', async () => {
    const user = userEvent.setup();
    const { container } = renderWithProviders(<PropertyRegistrationForm />);

    const deedHashInput = screen.getByLabelText(/property deed hash \(manual entry\)/i);

    // Test invalid deed hash - missing 0x
    await user.type(deedHashInput, '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');

    // Submit the form by clicking the submit button
    const submitButton = screen.getByRole('button', { name: /register property/i });

    // Use act to ensure all state updates complete
    await act(async () => {
      fireEvent.click(submitButton);
      // Wait a bit for React to process the state updates
      await new Promise(resolve => setTimeout(resolve, 100));
    });

    // Wait for validation errors to be rendered
    await waitFor(() => {
      const errorElement = screen.getByText(/Deed hash must be a 0x-prefixed 66-character hexadecimal string/i);
      expect(errorElement).toBeInTheDocument();
    }, { timeout: 2000 });

    // Should not call API due to validation failure
    expect(apiClient.registerProperty).not.toHaveBeenCalled();
  });

  it('validates rental agreement URI format', async () => {
    const user = userEvent.setup();
    const { container } = renderWithProviders(<PropertyRegistrationForm />);

    // Fill required fields first with valid data
    await user.type(screen.getByLabelText(/property address/i), '123 Main St, London, UK');
    await user.type(screen.getByLabelText(/property deed hash \(manual entry\)/i), '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    fireEvent.change(screen.getByLabelText(/raw metadata \(json\)/i), { target: { value: '{"test": "data"}' } });

    // Test invalid URI
    const uriInput = screen.getByLabelText(/rental agreement uri \(manual entry\)/i);
    await user.type(uriInput, 'invalid-url');

    // Submit the form by clicking the submit button
    const submitButton = screen.getByRole('button', { name: /register property/i });
    await act(async () => {
      fireEvent.click(submitButton);
    });

    // Wait for validation errors to be rendered
    await waitFor(() => {
      const errorElement = screen.getByText(/invalid uri format/i);
      expect(errorElement).toBeInTheDocument();
    }, { timeout: 2000 });

    // Should not call API due to validation failure
    expect(apiClient.registerProperty).not.toHaveBeenCalled();
  });

  it('validates metadata JSON format', async () => {
    const user = userEvent.setup();
    const { container } = renderWithProviders(<PropertyRegistrationForm />);

    // Fill required fields
    await user.type(screen.getByLabelText(/property address/i), '123 Main St, London, UK');
    await user.type(screen.getByLabelText(/property deed hash \(manual entry\)/i), '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    await user.type(screen.getByLabelText(/rental agreement uri \(manual entry\)/i), 'https://example.com/agreement.pdf');

    // Test invalid JSON
    fireEvent.change(screen.getByLabelText(/raw metadata \(json\)/i), { target: { value: '{"invalid": json}' } });

    // Submit the form by clicking the submit button
    const submitButton = screen.getByRole('button', { name: /register property/i });
    await act(async () => {
      fireEvent.click(submitButton);
    });

    // Wait for validation errors to be rendered
    await waitFor(() => {
      const errorElement = screen.getByText(/metadata must be valid json/i);
      expect(errorElement).toBeInTheDocument();
    }, { timeout: 2000 });

    // Should not call API due to validation failure
    expect(apiClient.registerProperty).not.toHaveBeenCalled();
  });

  it('submits form successfully with ERC-721 + ERC-20 standard', async () => {
    const user = userEvent.setup();
    const { container } = renderWithProviders(<PropertyRegistrationForm />);

    // Mock successful API response
    const mockResponse = {
      data: {
        property_id: 1,
        blockchain_token_id: 123,
        tx_hash: '0xabcdef1234567890',
      },
      duration: 1500,
      status: 200,
    };
    apiClient.registerProperty.mockResolvedValue(mockResponse);

    // Fill form with valid data
    await user.type(screen.getByLabelText(/property address/i), '123 Main St, London, UK');
    await user.type(screen.getByLabelText(/property deed hash \(manual entry\)/i), '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    await user.type(screen.getByLabelText(/rental agreement uri \(manual entry\)/i), 'https://example.com/test.pdf');
    fireEvent.change(screen.getByLabelText(/raw metadata \(json\)/i), { target: { value: '{"test": "data"}' } });

    // Submit form
    const submitButton = screen.getByRole('button', { name: /register property/i });
    fireEvent.click(submitButton);

    // Verify API call was made
    await waitFor(() => {
      expect(apiClient.registerProperty).toHaveBeenCalled();
    });
  });

  it('displays error on API failure', async () => {
    const user = userEvent.setup();
    const { container } = renderWithProviders(<PropertyRegistrationForm />);

    // Mock API failure
    apiClient.registerProperty.mockRejectedValue({
      message: 'Blockchain error',
      status: 500,
      originalError: new Error('Network error'),
    });

    // Fill form
    await user.type(screen.getByLabelText(/property address/i), '123 Main St, London, UK');
    await user.type(screen.getByLabelText(/property deed hash \(manual entry\)/i), '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    await user.type(screen.getByLabelText(/rental agreement uri \(manual entry\)/i), 'https://example.com/agreement.pdf');
    fireEvent.change(screen.getByLabelText(/raw metadata \(json\)/i), { target: { value: '{"test": "data"}' } });

    // Submit the form by clicking the submit button
    const submitButton = screen.getByRole('button', { name: /register property/i });
    await act(async () => {
      fireEvent.click(submitButton);
    });

    // Verify error display
    await waitFor(() => {
      const errorElement = screen.getByText('Blockchain error');
      expect(errorElement).toBeInTheDocument();
    }, { timeout: 2000 });
  });

  it('shows loading state during submission', async () => {
    const user = userEvent.setup();
    const { container } = renderWithProviders(<PropertyRegistrationForm />);

    // Mock slow API response
    apiClient.registerProperty.mockImplementation(() =>
      new Promise(resolve => setTimeout(() => resolve({
        data: { property_id: 1, blockchain_token_id: 123 },
        duration: 1000,
        status: 200,
      }), 100))
    );

    // Fill form and submit
    await user.type(screen.getByLabelText(/property address/i), '123 Main St, London, UK');
    await user.type(screen.getByLabelText(/property deed hash \(manual entry\)/i), '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef');
    await user.type(screen.getByLabelText(/rental agreement uri \(manual entry\)/i), 'https://example.com/agreement.pdf');
    fireEvent.change(screen.getByLabelText(/raw metadata \(json\)/i), { target: { value: '{"test": "data"}' } });

    // Submit the form by clicking the submit button
    const submitButton = screen.getByRole('button', { name: /register property/i });
    await act(async () => {
      fireEvent.click(submitButton);
    });

    // Verify loading state
    await waitFor(() => {
      expect(screen.getByRole('progressbar')).toBeInTheDocument();
    }, { timeout: 2000 });

    // Wait for completion
    await waitFor(() => {
      expect(screen.queryByRole('progressbar')).not.toBeInTheDocument();
    }, { timeout: 3000 });
  });

  it('displays current token standard with ERC-20 label', () => {
    renderWithProviders(<PropertyRegistrationForm />);

    expect(screen.getByText(/current token standard:/i)).toBeInTheDocument();
    expect(screen.getByText(/erc-721 \+ erc-20 \(separate contracts\)/i)).toBeInTheDocument();
  });
});

