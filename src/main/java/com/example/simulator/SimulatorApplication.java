package com.example.simulator;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@SpringBootApplication
// NOTE: repository packages are listed explicitly. A new repository package MUST be
// added here or its beans will not be found and the application will fail to start.
@EnableJpaRepositories(basePackages = {
		"com.example.simulator.repository", // platform + Simulation 1
		"com.example.simulator.simulation", // Simulation 1 faculty debrief
		"com.example.simulator.sim1",       // Simulator 1 Set-B construct engine
		"com.example.simulator.sim2",       // Simulator 2 (Meridian Retail QBR) engine
		"com.example.simulator.faculty"     // platform-wide faculty control layer
})
public class SimulatorApplication {

	 private static final Logger log =
	            LoggerFactory.getLogger(SimulatorApplication.class);
	
	public static void main(String[] args) {
		SpringApplication.run(SimulatorApplication.class, args);
		log.info(">>> APPLICATION STARTED <<<");
	}

}
