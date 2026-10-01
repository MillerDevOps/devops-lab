package com.millerdevops.javaapi;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ApiController {

    // La versión llega por variable de entorno (la pone el pipeline = hash del commit)
    @Value("${APP_VERSION:dev}")
    private String version;

    @GetMapping("/")
    public Map<String, String> info() {
        return Map.of(
                "app", "java-api",
                "version", version,
                "lenguaje", "Java 17 + Spring Boot");
    }

    @GetMapping("/api/saludo")
    public Map<String, String> saludo(@RequestParam(defaultValue = "mundo") String nombre) {
        return Map.of("mensaje", "Hola, " + nombre + "!");
    }
}
