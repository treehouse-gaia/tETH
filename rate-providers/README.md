# Rate Providers Documentation

## Lido APR Rate Provider

### Overview

This document describes the expected behavior and calculations for the Lido APR (Annual Percentage Rate) Rate Provider. The provider is designed to simulate a 2.8% APY (Annual Percentage Yield) for Lido staking rewards.

### Precision and Calculations

- **Precision**: All calculations use 1e27 (1 with 27 zeros) as the base unit for precision.
- **Expected APY**: 2.8%

### Daily Rate Progression

The rate evolves daily according to the following pattern:

- Deployment (t0): 1e27
- Day 1 (t1): 1e27 + 76712328767123287671232
- Day 2 (t2): 1e27 + (76712328767123287671232 \* 2)
- Day n (tn): 1e27 + (76712328767123287671232 \* n)

Where `n` is the number of days since deployment.

### Precision Considerations

#### 1e36 Precision

When calculated with 1e36 precision, the APY is approximately:

```
0.0280000000000000000000000000000000001
```

This is essentially equivalent to 2.8%.

#### 1e27 Precision

When using 1e27 precision (as implemented), the APY is approximately:

```
0.0279999999999999999999999999999999999
```

#### Deviation

The deviation between 1e36 and 1e27 precision calculations is negligible:

```
≈1×10^-36
```
