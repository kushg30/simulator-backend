package com.example.simulator;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@SpringBootApplication
@EnableJpaRepositories(basePackages = {
		"com.example.simulator.repository", // platform + Simulation 1
		"com.example.simulator.sim2"        // Simulator 2 (Meridian Retail QBR) engine
})
public class SimulatorApplication {

	 private static final Logger log =
	            LoggerFactory.getLogger(SimulatorApplication.class);
	
	public static void main(String[] args) {
		SpringApplication.run(SimulatorApplication.class, args);
		log.info(">>> APPLICATION STARTED <<<");
	}

}
