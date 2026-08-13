-- sim2 v4 (phase 3b): structured per-round submission fields.
-- The frontend now assembles the graded fields into the MULTI typed answer, so
-- Rounds 4 and 5 must grade all four fields (product, product count, month,
-- month count), not just product + month.
UPDATE sim2_answer_key
   SET canonical_answer = 'Notebook Set;35;April;90'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002'
   AND round_number IN (4, 5);
