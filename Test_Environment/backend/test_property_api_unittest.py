import unittest
import httpx
from unittest.mock import Mock, patch
import json
import time

class TestPropertyAPI(unittest.TestCase):
    def setUp(self):
        self.base_url = 'http://localhost:8000'
        self.client = httpx.Client(base_url=self.base_url)
        self.mock_web3_service = Mock()
        
    def tearDown(self):
        self.client.close()
        
    def test_register_property_success(self):
        property_data = {
            'property_address': '123 Test Street, Test City, TC 12345',
            'deed_hash': 'QmTest1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            'rental_agreement_uri': 'ipfs://QmTestRentalAgreement1234567890abcdef',
            'token_standard': 'ERC721'
        }
        
        mock_response_data = {
            'property_id': 1,
            'blockchain_token_id': 1,
            'tx_hash': '0x1234567890abcdef',
            'metadata_uri': 'ipfs://QmMetadata1234567890abcdef',
            'status': 'success',
            'message': 'Property registered successfully'
        }
        
        start_time = time.time()
        
        with patch('httpx.Client', return_value=Mock()) as mock_client:
            mock_client_instance = Mock()
            mock_client_instance.post.return_value = httpx.Response(
                status_code=201,
                json=mock_response_data
            )
            mock_client.return_value = mock_client_instance
            
            response = mock_client_instance.post('/properties/register', json=property_data)
            elapsed_time = time.time() - start_time
            
            self.assertEqual(response.status_code, 201)
            data = response.json()
            
            self.assertIn('property_id', data)
            self.assertIn('blockchain_token_id', data)
            self.assertEqual(data['blockchain_token_id'], 1)
            self.assertIn('tx_hash', data)
            self.assertIn('metadata_uri', data)
            self.assertEqual(data['status'], 'success')
            self.assertEqual(data['message'], 'Property registered successfully')
            
            print(f'[TEST_METRICS] Property registration API time: {elapsed_time:.3f}s')

if __name__ == '__main__':
    unittest.main()
