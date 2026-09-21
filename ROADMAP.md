# Roadmap

Where the project goes next. The [README](README.md) describes what exists today; this
file is for what doesn't yet, and for the open questions we already know about.

## Where we are

`Caixa API -> data/raw -> transient.raw -> bronze -> silver -> gold`, all rebuilt from
`data/raw/` with `./rebuild.sh`. The modeling is done: a typed bronze layer, a silver
star schema, and `gold.cube_contest` (one wide row per contest, balls as arrays, winners
per tier). The next phase is about *using* the data.

## Next: statistics and probability

Ideas for notebooks in `workspace/`, roughly in the order worth doing them.

1. **Do the draws look fair?** Test that the 25 balls come out equally often
   (chi-square), and look at pairs, runs, the sum of the 15 balls and the even/odd
   split. The expected result is that everything looks like a fair draw; the value is in
   confirming it, and in knowing the data is sound.
2. **Theory versus observed.** The chance of each tier is hypergeometric,
   `C(15, k) * C(10, 15 - k) / C(25, 15)` for `k` hits. Compare it with the winners
   actually reported per tier in `tier_*_winner_qtty`.
3. **Payout and expected value.** `collected_amt` against the sum of
   `winners * prize` over the tiers gives the share of sales that returns as prizes,
   and from it the expected value of a bet. It needs no outside data.
4. **Sales behavior.** How `collected_amt` moves with the accumulated prize, the day of
   the week, holidays and the Independence draws. This is where a real effect exists.
5. **Gaps.** For each ball, how many contests it has gone without coming out.
   Descriptive only.

### Ground rules

- Draws are independent: past results say nothing about the next one, so none of this
  predicts the numbers. Report it as description and validation, never as a method.
- With 25 balls and thousands of draws some pattern will look significant by chance.
  Report p-values with a multiple-testing correction, and state how many things were
  tried.
- Machine learning fits the *money* (`collected_amt` from accumulated prize, weekday and
  holidays), not the draw. A model that "predicts" the balls should score exactly at
  chance, which is a useful sanity check in itself.

### Tooling

- Add `scipy`, `statsmodels` and `matplotlib` to the `notebook` dependency group
  (`uv add --group notebook ...`).
- Stay with pandas, SQL or DuckDB. PySpark would only add a JVM for 3,784 contests.
- Optionally, a project skill (via `skill-creator`) that records these rules and the
  data caveats below, so every analysis session starts from them.

## Possible gold models

- Ball frequency and gap per ball, one row per ball.
- A pair matrix (how often two balls came out together).
- Cube variants: one flag column per ball (25) or one column per draw position (15),
  if arrays turn out to be awkward for the analysis.

## Known data limits

- **Locations exist only for the top tier.** The winning-municipalities list has no tier
  in the source. It exists for all 3,301 contests with a 15-hit winner and for none
  without, so the cube names it `tier_15_*`. That is an inference, not something the
  Caixa documents. Tiers 11 to 14 have no location data at all.
- **Municipality winners don't always add up.** Their sum differs from
  `tier_15_winner_qtty` in 79 contests, by a few units (one case by 21). Both are kept
  as the source sent them.
- **The price of a bet is not in the data**, and it changed over the years. Estimating
  the number of bets per contest needs a seed with the price by period.
- **Holidays come from BrasilAPI**, which lists everything as national, including
  Carnaval, Sexta-feira Santa, Pascoa and Corpus Christi. The seed is committed;
  `uv run lotofacil holidays` extends it (about once a year), and the
  `dim_date_years_have_holidays` test fails when a year is missing. A holiday type
  column or a `business_day_flg` would need a decision on what counts.
- **Bronze text stays as the source sent it.** Upper-casing and accent stripping happen
  in silver, so bronze and silver text columns are deliberately different.
