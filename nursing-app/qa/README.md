# Full Quality Gate

This folder defines the executable acceptance gate:

- Full regression
- Stress testing
- Fault injection

## What counts as each category

- Regression:
  - `backend-springboot`: `mvn test`
  - `admin-vue3/vue-project`: `npm run test -- --run`
  - `android-flutter/nursing_app`: `flutter test`
- Stress:
  - Included in backend test suite via `PaymentControllerResilienceTest.payOrderShouldSurviveBurstRequestsInLoop`
- Fault injection:
  - Included in backend test suite via `PaymentControllerResilienceTest.payOrderShouldFailFastWhenAlipayServiceThrows`

## One-command gate

```powershell
pwsh -File .\qa\run_full_gate.ps1
```

If Flutter tooling is unstable on the current machine, run:

```powershell
pwsh -File .\qa\run_full_gate.ps1 -SkipFlutter
```

## Notes

- The backend resilience tests are part of `mvn test`, so stress and fault injection are always executed when backend tests run.
- Frontend API integration tests remain intentionally skipped (`describe.skip`) unless a live backend target is provisioned.
