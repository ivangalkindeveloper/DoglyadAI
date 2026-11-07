-- Only the isolated Compose database created for this run may execute this fixture.
-- This is synthetic ledger state, not a verified purchase or a payment test.
DO $$ BEGIN
  IF current_database() <> 'regression' THEN RAISE EXCEPTION 'Wrong database'; END IF;
  IF (SELECT count(*) FROM billing_owners) <> 1 THEN RAISE EXCEPTION 'Expected exactly one fresh test owner'; END IF;
END $$;
DELETE FROM billing_usage WHERE id LIKE 'f0000000-0000-4000-8000-%';
DELETE FROM billing_subscriptions WHERE id = '00000000-0000-4000-8000-000000000001';
