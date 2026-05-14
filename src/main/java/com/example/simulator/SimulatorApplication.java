package com.example.simulator;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@SpringBootApplication
@EnableJpaRepositories(basePackages = "com.example.simulator.repository")
public class SimulatorApplication {

	 private static final Logger log =
	            LoggerFactory.getLogger(SimulatorApplication.class);
	
	public static void main(String[] args) {
		SpringApplication.run(SimulatorApplication.class, args);
		log.info(">>> APPLICATION STARTED <<<");
	}

}
