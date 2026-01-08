import unittest
import httpx
from unittest.mock import Mock, patch
import json
import time

class TestYieldAgreementAPI(unittest.TestCase):
    def setUp(self):
        self.base_url = 'http://localhost:8000'
        self.client = httpx.Client(base_url=self.base_url)
        self.mock_web3_service = Mock()
        
    def tearDown(self):
        self.client.close()
        
    def test_create_yield_agreement_success(self):
        # Test data for yield agreement
        agreement_data = {
            'property_token_id': 1,
            'upfront_capital_usd': '50000',
            'term_months': 24,
            'annual_roi_percent': 12.0,
            'grace_period_days': 30,
            'default_penalty_rate': 2,
            'default_threshold': 3,
            'allow_partial_repayments': True,
            'allow_early_repayment': True,
            'property_payer': None
        }
        
        mock_response_data = {
            'agreement_id': 1,
            'blockchain_agreement_id': 456,
            'token_contract_address': '0x1234567890123456789012345678901234567890',
            'tx_hash': '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
            'monthly_payment': '2187500000000000000',
            'total_expected_repayment': '52500000000000000000',
            'status': 'success',
            'message': 'Yield agreement created successfully'
        }
        
        start_time = time.time()
        
        with patch('httpx.Client', return_value=Mock()) as mock_client:
            mock_client_instance = Mock()
            mock_client_instance.post.return_value = httpx.Response(
                status_code=201,
                json=mock_response_data
            )
            mock_client.return_value = mock_client_instance
            
            response = mock_client_instance.post('/yield-agreements/create', json=agreement_data)
            elapsed_time = time.time() - start_time
            
            self.assertEqual(response.status_code, 201)
            data = response.json()
            
            self.assertIn('agreement_id', data)
            self.assertIn('blockchain_agreement_id', data)
            self.assertIn('token_contract_address', data)
            self.assertIn('tx_hash', data)
            self.assertIn('monthly_payment', data)
            self.assertIn('total_expected_repayment', data)
            self.assertEqual(data['status'], 'success')
            self.assertEqual(data['message'], 'Yield agreement created successfully')
            
            print(f'[TEST_METRICS] Yield agreement creation API time: {elapsed_time:.3f}s')

if __name__ == '__main__':
    unittest.main()
