"""
Comprehensive tests for Hospital Referral API
"""
import pytest
import asyncio
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
import pandas as pd
from main import app
from hospital_recommender import recommend_hospitals

client = TestClient(app)

class TestHospitalAPI:
    
    def test_health_check(self):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
    
    def test_recommend_hospitals_success(self):
        """Test successful hospital recommendation"""
        response = client.get("/recommend-hospitals?lat=3.8480&lon=11.5021&top_n=3")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) <= 3
        
        if data:  # If hospitals found
            hospital = data[0]
            required_fields = ['facility_name', 'facility_type', 'latitude', 'longitude', 'distance_km']
            for field in required_fields:
                assert field in hospital
    
    def test_recommend_hospitals_invalid_coordinates(self):
        """Test with invalid coordinates"""
        response = client.get("/recommend-hospitals?lat=91&lon=181")
        assert response.status_code == 422  # Validation error
    
    def test_recommend_hospitals_with_type_filter(self):
        """Test hospital recommendation with type filter"""
        response = client.get("/recommend-hospitals?lat=3.8480&lon=11.5021&type=District")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
    
    def test_recommend_hospitals_edge_cases(self):
        """Test edge cases"""
        # Test with maximum top_n
        response = client.get("/recommend-hospitals?lat=3.8480&lon=11.5021&top_n=50")
        assert response.status_code == 200
        
        # Test with minimum top_n
        response = client.get("/recommend-hospitals?lat=3.8480&lon=11.5021&top_n=1")
        assert response.status_code == 200
        
        # Test with invalid top_n
        response = client.get("/recommend-hospitals?lat=3.8480&lon=11.5021&top_n=0")
        assert response.status_code == 422

class TestHospitalRecommender:
    
    def test_recommend_hospitals_basic(self):
        """Test basic hospital recommendation functionality"""
        coords = (3.8480, 11.5021)
        result = recommend_hospitals(coords, top_n=5)
        
        assert isinstance(result, pd.DataFrame)
        expected_columns = ['facility_name', 'facility_type', 'latitude', 'longitude', 'distance_km']
        for col in expected_columns:
            assert col in result.columns
    
    def test_recommend_hospitals_with_filter(self):
        """Test hospital recommendation with type filter"""
        coords = (3.8480, 11.5021)
        result = recommend_hospitals(coords, top_n=5, required_type="District")
        
        assert isinstance(result, pd.DataFrame)
        if not result.empty:
            # Check that all results contain the filter term
            assert all("District" in str(facility_type) for facility_type in result['facility_type'])
    
    def test_recommend_hospitals_invalid_coords(self):
        """Test with invalid coordinates"""
        with pytest.raises(ValueError):
            recommend_hospitals((91, 181))
    
    def test_recommend_hospitals_empty_result(self):
        """Test when no hospitals match filter"""
        coords = (3.8480, 11.5021)
        result = recommend_hospitals(coords, required_type="NonexistentType")
        
        assert isinstance(result, pd.DataFrame)
        assert result.empty

class TestPerformance:
    
    def test_api_response_time(self):
        """Test API response time"""
        import time
        
        start_time = time.time()
        response = client.get("/recommend-hospitals?lat=3.8480&lon=11.5021")
        end_time = time.time()
        
        assert response.status_code == 200
        assert (end_time - start_time) < 2.0  # Should respond within 2 seconds
    
    def test_concurrent_requests(self):
        """Test handling of concurrent requests"""
        import concurrent.futures
        
        def make_request():
            return client.get("/recommend-hospitals?lat=3.8480&lon=11.5021")
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        # All requests should succeed
        for response in results:
            assert response.status_code == 200

class TestErrorHandling:
    
    def test_missing_parameters(self):
        """Test missing required parameters"""
        response = client.get("/recommend-hospitals")
        assert response.status_code == 422
    
    def test_invalid_parameter_types(self):
        """Test invalid parameter types"""
        response = client.get("/recommend-hospitals?lat=invalid&lon=11.5021")
        assert response.status_code == 422
    
    @patch('hospital_recommender.recommend_hospitals')
    def test_internal_server_error(self, mock_recommend):
        """Test internal server error handling"""
        mock_recommend.side_effect = Exception("Database error")
        
        response = client.get("/recommend-hospitals?lat=3.8480&lon=11.5021")
        assert response.status_code == 500
        assert "error" in response.json() or "detail" in response.json()

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
