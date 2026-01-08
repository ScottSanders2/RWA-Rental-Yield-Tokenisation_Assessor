import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { CssBaseline } from '@mui/material';
import { SnackbarProvider } from 'notistack';

// Context providers
import { TokenStandardProvider } from './context/TokenStandardContext';
import { PriceProvider } from './context/PriceContext';
import { WalletProvider } from './context/WalletContext';

// Components
import NavigationAppBar from './components/AppBar';

// Pages
import Dashboard from './pages/Dashboard';
import PropertyRegistration from './pages/PropertyRegistration';
import YieldAgreementCreation from './pages/YieldAgreementCreation';
import YieldAgreementDetail from './pages/YieldAgreementDetail';
import YieldAgreementsList from './pages/YieldAgreementsList';
import PropertiesList from './pages/PropertiesList';
import Governance from './pages/Governance';
import GovernanceProposalForm from './components/GovernanceProposalForm';
import GovernanceProposalDetail from './pages/GovernanceProposalDetail';
import MarketplaceListings from './pages/MarketplaceListings';
import CreateListingForm from './components/CreateListingForm';
import BuySharesForm from './components/BuySharesForm';
import Portfolio from './pages/Portfolio';
import AnalyticsDashboard from './pages/AnalyticsDashboard';
import KYCPage from './pages/KYCPage';
import KYCAdminPage from './pages/KYCAdminPage';

/**
 * Main App component with routing and context providers
 * @returns {React.ReactElement} App component
 */
function App() {
  return (
    <SnackbarProvider 
      maxSnack={3} 
      anchorOrigin={{ vertical: 'top', horizontal: 'center' }}
      autoHideDuration={6000}
    >
      <CssBaseline>
        <WalletProvider>
          <TokenStandardProvider>
            <PriceProvider>
                <BrowserRouter>
                <NavigationAppBar />
                <Routes>
                  <Route path="/" element={<Dashboard />} />
                  <Route path="/properties" element={<PropertiesList />} />
                  <Route path="/properties/register" element={<PropertyRegistration />} />
                  <Route path="/yield-agreements" element={<YieldAgreementsList />} />
                  <Route path="/yield-agreements/create" element={<YieldAgreementCreation />} />
                  <Route path="/yield-agreements/create/:propertyTokenId" element={<YieldAgreementCreation />} />
                  <Route path="/yield-agreements/:id" element={<YieldAgreementDetail />} />
                  
                  {/* Governance Routes */}
                  <Route path="/governance" element={<Governance />} />
                  <Route path="/governance/create" element={<GovernanceProposalForm />} />
                  <Route path="/governance/proposals/:proposalId" element={<GovernanceProposalDetail />} />
                  
                  {/* Marketplace Routes (Secondary Market) */}
                  <Route path="/marketplace" element={<MarketplaceListings />} />
                  <Route path="/marketplace/create" element={<CreateListingForm />} />
                  <Route path="/marketplace/create/:agreementId" element={<CreateListingForm />} />
                  <Route path="/marketplace/listings/:listingId/buy" element={<BuySharesForm />} />
                  
                  {/* Analytics Routes (Iteration 13) */}
                  <Route path="/analytics" element={<AnalyticsDashboard />} />
                  
                  <Route path="/portfolio" element={<Portfolio />} />
                  
                  {/* KYC Verification */}
                  <Route path="/kyc" element={<KYCPage />} />
                  
                  {/* KYC Admin (Iteration 14) */}
                  <Route path="/kyc-admin" element={<KYCAdminPage />} />
                </Routes>
              </BrowserRouter>
            </PriceProvider>
          </TokenStandardProvider>
        </WalletProvider>
      </CssBaseline>
    </SnackbarProvider>
  );
}

export default App;
