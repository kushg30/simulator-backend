package com.example.simulator.service;

import java.util.List;
import java.util.Map;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import com.example.simulator.repository.ArtifactQueryRepository;

/**
 * CEO Decision Timeout Policy (script 1.7) — the scheduler half.
 *
 * <p>Every round-ending CEO decision has a hard deadline: the round's final timestamp. If the CEO
 * has not submitted by a two-minute grace after that deadline, the platform auto-advances and logs
 * the outcome as "No decision submitted" — a leadership failure mode in its own right, not a glitch.
 *
 * <p>This bean only finds candidate rounds and hands each to {@link Sim1RoundAdvancer}, whose
 * per-round transaction does the actual penalty/log/advance. Keeping the advance in a separate bean
 * means each team is its own transaction (via the Spring proxy) — one team's failure can't roll back
 * another's, and the {@code @Modifying} queries get the transaction they require.
 */
@Service
public class Sim1TimeoutService {

	private final ArtifactQueryRepository repository;
	private final Sim1RoundAdvancer advancer;

	public Sim1TimeoutService(ArtifactQueryRepository repository, Sim1RoundAdvancer advancer) {
		this.repository = repository;
		this.advancer = advancer;
	}

	/** Scans active Sim-1 rounds every 10s and advances any whose timer has ended (time-boxed rounds). */
	@Scheduled(fixedDelay = 10_000L, initialDelay = 15_000L)
	public void scan() {
		List<Map<String, Object>> rounds;
		try {
			rounds = repository.findActiveSim1Rounds();
		} catch (Exception e) {
			return; // transient DB/connection issue — try again next tick
		}
		for (Map<String, Object> r : rounds) {
			try {
				advancer.evaluate(r);
			} catch (Exception e) {
				// One team's failure must not stop the others; try again next tick.
			}
		}
	}
}
