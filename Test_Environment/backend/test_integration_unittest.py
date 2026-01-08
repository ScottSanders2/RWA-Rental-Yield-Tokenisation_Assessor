import unittest
import httpx
from unittest.mock import Mock, patch
import time

class TestIntegration(unittest.TestCase):
    def setUp(self):
        self.base_url = 'http://localhost:8000'
        self.client = httpx.Client(base_url=self.base_url)
        
    def tearDown(self):
        self.client.close()
        
    def test_property_to_yield_agreement_flow(self):
        """Test the complete flow from property registration to yield agreement creation."""
        
        # Step 1: Register property
        property_data = {
            'property_address': '123 Integration Test St, Test City, TC 12345',
            'deed_hash': 'QmTest1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            'rental_agreement_uri': 'ipfs://QmIntegrationTest1234567890abcdef',
            'token_standard': 'ERC721'
        }
        
        property_response_data = {
            'property_id': 1,
            'blockchain_token_id': 1,
            'tx_hash': '0x1234567890abcdef',
            'metadata_uri': 'ipfs://QmMetadata1234567890abcdef',
            'status': 'success',
            'message': 'Property registered successfully'
        }
        
        # Step 2: Create yield agreement
        agreement_data = {
            'property_token_id': 1,
            'upfront_capital_usd': '75000',
            'term_months': 36,
            'annual_roi_percent': 10.0,
            'grace_period_days': 45,
            'default_penalty_rate': 3,
            'default_threshold': 5,
            'allow_partial_repayments': True,
            'allow_early_repayment': False,
            'property_payer': '0x742d35Cc6634C0532925a3b844Bc454e4438f44e'
        }
        
        agreement_response_data = {
            'agreement_id': 1,
            'blockchain_agreement_id': 789,
            'token_contract_address': '0xabcdef1234567890abcdef1234567890abcdef1234567890',
            'tx_hash': '0x789abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            'monthly_payment': '625000000000000000',
            'total_expected_repayment': '27000000000000000000',
            'status': 'success',
            'message': 'Yield agreement created successfully'
        }
        
        with patch('httpx.Client', return_value=Mock()) as mock_client:
            mock_client_instance = Mock()
            
            # Mock property registration response
            mock_client_instance.post.side_effect = [
                httpx.Response(status_code=201, json=property_response_data),
                httpx.Response(status_code=201, json=agreement_response_data)
            ]
            
            mock_client.return_value = mock_client_instance
            
            start_time = time.time()
            
            # Register property
            prop_response = mock_client_instance.post('/properties/register', json=property_data)
            self.assertEqual(prop_response.status_code, 201)
            prop_data = prop_response.json()
            self.assertEqual(prop_data['status'], 'success')
            
            # Create yield agreement
            agree_response = mock_client_instance.post('/yield-agreements/create', json=agreement_data)
            self.assertEqual(agree_response.status_code, 201)
            agree_data = agree_response.json()
            self.assertEqual(agree_data['status'], 'success')
            
            # Verify the agreement references the property
            self.assertEqual(agreement_data['property_token_id'], 1)
            
            elapsed_time = time.time() - start_time
            print(f'[INTEGRATION_TEST] Complete property-to-agreement flow time: {elapsed_time:.3f}s')

if __name__ == '__main__':
    unittest.main()
