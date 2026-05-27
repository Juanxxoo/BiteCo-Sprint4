package com.biteco.clientes.service;
 
import com.biteco.clientes.entity.Client;
import com.biteco.clientes.repository.ClientRepository;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
 
import java.util.*;
 
@Service
public class ClientService {
 
    private final ClientRepository clientRepository;
    private final RestTemplate restTemplate;
 
    @Value("${reports.service.url}")
    private String reportsServiceUrl;
 
    @Value("${projects.service.url}")
    private String projectsServiceUrl;
 
    public ClientService(ClientRepository clientRepository) {
        this.clientRepository = clientRepository;
        this.restTemplate = new RestTemplate();
    }
 
    @PostConstruct
    public void seedData() {
        if (clientRepository.count() > 0) return;
 
        clientRepository.saveAll(List.of(
            new Client("client-001", "Empresa Alpha S.A.S", "alpha@empresa.com", "enterprise"),
            new Client("client-002", "Empresa Beta Ltda",  "beta@empresa.com",  "professional"),
            new Client("client-003", "Empresa Gamma Corp", "gamma@empresa.com", "starter")
        ));
    }
 
    public List<Client> getClients() {
        return clientRepository.findAll();
    }
 
    public Optional<Client> getClient(String clientId) {
        return clientRepository.findById(clientId);
    }
 
    public Map<String, Object> tamperReport(String reportId, String projectId, String field, Object newValue) {
        long start = System.currentTimeMillis();
 
        Map<String, Object> body = new HashMap<>();
        body.put("report_id", reportId);
        body.put("project_id", projectId);
        body.put("field", field);
        body.put("new_value", newValue);
 
        Map<String, Object> result = new HashMap<>();
 
        try {
            String url = reportsServiceUrl + "/reports/tamper/";
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(body, headers);
            ResponseEntity<Map> responseEntity = restTemplate.postForEntity(url, request, Map.class);
            Map response = responseEntity.getBody();
 
            long elapsed = System.currentTimeMillis() - start;
 
            result.put("message", "Modificación no autorizada simulada");
            result.put("report_id", reportId);
            result.put("project_id", projectId);
            result.put("field_modified", field);
            result.put("new_value", newValue);
            result.put("tampering_simulated", true);
            result.put("reports_service_response", response);
            result.put("tampering_time_ms", elapsed);
            result.put("asr_threshold_ms", 400);
            result.put("asr_met", elapsed < 400);
 
        } catch (Exception e) {
            result.put("error", "No se pudo conectar a ms-reportes: " + e.getMessage());
            result.put("tampering_simulated", false);
        }
 
        return result;
    }
}