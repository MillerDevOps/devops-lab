package com.millerdevops.javaapi;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ApiController.class)
class ApiControllerTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void infoDevuelveElNombreDeLaApp() throws Exception {
        mvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.app").value("java-api"));
    }

    @Test
    void saludoUsaElNombreRecibido() throws Exception {
        mvc.perform(get("/api/saludo").param("nombre", "Miller"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mensaje").value("Hola, Miller!"));
    }
}
