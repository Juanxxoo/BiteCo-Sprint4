package com.biteco.clientes.controller;

import com.biteco.clientes.entity.Client;
import com.biteco.clientes.service.ClientService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
public class ClientController {

    private final ClientService clientService;

    public ClientController(ClientService clientService) {
        this.clientService = clientService;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok", "service", "ms-clientes");
    }

    @GetMapping("/clients")
    public List<Client> getClients() {
        return clientService.getClients();
    }

    @GetMapping("/clients/{clientId}")
    public ResponseEntity<Client> getClient(@PathVariable String clientId) {
        Optional<Client> client = clientService.getClient(clientId);
        return client.map(ResponseEntity::ok)
                     .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/clients/tamper-project-report")
    public Map<String, Object> tamperReport(@RequestBody Map<String, Object> body) {
        String reportId  = (String) body.get("report_id");
        String projectId = (String) body.get("project_id");
        String field     = (String) body.getOrDefault("field", "total_cost");
        Object newValue  = body.getOrDefault("new_value", 999999);

        return clientService.tamperReport(reportId, projectId, field, newValue);
    }
}
