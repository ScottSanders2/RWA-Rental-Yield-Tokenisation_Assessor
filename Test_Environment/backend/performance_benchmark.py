import unittest
import httpx
from unittest.mock import Mock, patch
import time
import statistics

class PerformanceBenchmark(unittest.TestCase):
    def setUp(self):
        self.base_url = 'http://localhost:8000'
        self.client = httpx.Client(base_url=self.base_url)
        
    def tearDown(self):
        self.client.close()
        
    def test_api_response_times(self):
        """Benchmark API response times for key endpoints."""
        
        # Property registration benchmark
        property_data = {
            'property_address': '123 Benchmark St, Perf City, PC 12345',
            'deed_hash': 'QmBenchmark1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            'rental_agreement_uri': 'ipfs://QmBenchmarkTest1234567890abcdef',
            'token_standard': 'ERC721'
        }
        
        property_response_data = {
            'property_id': 1,
            'blockchain_token_id': 1,
            'tx_hash': '0xbenchmark1234567890abcdef',
            'metadata_uri': 'ipfs://QmBenchmarkMetadata1234567890abcdef',
            'status': 'success',
            'message': 'Property registered successfully'
        }
        
        # Yield agreement benchmark
        agreement_data = {
            'property_token_id': 1,
            'upfront_capital_usd': '100000',
            'term_months': 24,
            'annual_roi_percent': 12.0,
            'grace_period_days': 30,
            'default_penalty_rate': 2,
            'default_threshold': 3,
            'allow_partial_repayments': True,
            'allow_early_repayment': True,
            'property_payer': None
        }
        
        agreement_response_data = {
            'agreement_id': 1,
            'blockchain_agreement_id': 456,
            'token_contract_address': '0xbenchmark1234567890abcdef1234567890abcdef1234567890',
            'tx_hash': '0xagreement1234567890abcdef1234567890abcdef1234567890abcdef',
            'monthly_payment': '4166666666666667000',
            'total_expected_repayment': '100000000000000000000',
            'status': 'success',
            'message': 'Yield agreement created successfully'
        }
        
        # Run benchmarks multiple times
        property_times = []
        agreement_times = []
        
        for i in range(10):  # Run 10 iterations for statistical significance
            with patch('httpx.Client', return_value=Mock()) as mock_client:
                mock_client_instance = Mock()
                mock_client_instance.post.side_effect = [
                    httpx.Response(status_code=201, json=property_response_data),
                    httpx.Response(status_code=201, json=agreement_response_data)
                ]
                mock_client.return_value = mock_client_instance
                
                # Benchmark property registration
                start_time = time.time()
                prop_response = mock_client_instance.post('/properties/register', json=property_data)
                property_times.append(time.time() - start_time)
                
                # Benchmark yield agreement creation
                start_time = time.time()
                agree_response = mock_client_instance.post('/yield-agreements/create', json=agreement_data)
                agreement_times.append(time.time() - start_time)
        
        # Calculate statistics
        prop_avg = statistics.mean(property_times)
        prop_min = min(property_times)
        prop_max = max(property_times)
        prop_stddev = statistics.stdev(property_times)
        
        agree_avg = statistics.mean(agreement_times)
        agree_min = min(agreement_times)
        agree_max = max(agreement_times)
        agree_stddev = statistics.stdev(agreement_times)
        
        print(f"[PERFORMANCE_BENCHMARK] Property Registration API:")
        print(f"  Average: {prop_avg:.4f}s")
        print(f"  Min: {prop_min:.4f}s")
        print(f"  Max: {prop_max:.4f}s")
        print(f"  StdDev: {prop_stddev:.4f}s")
        
        print(f"[PERFORMANCE_BENCHMARK] Yield Agreement Creation API:")
        print(f"  Average: {agree_avg:.4f}s")
        print(f"  Min: {agree_min:.4f}s")
        print(f"  Max: {agree_max:.4f}s")
        print(f"  StdDev: {agree_stddev:.4f}s")
        
        # Assert reasonable performance (under 100ms average)
        self.assertLess(prop_avg, 0.1, Property
