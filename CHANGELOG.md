# 1.2.2: 18.Jan.2022: Disable never-winning ratio by default

* Disable never-winning ratio by default, as we're not using it anymore for a long time

# 1.2.1: 4.Jan.2022: Improvement: Guard against invalid balances

* Add guard against invalid balances

# 1.2.0: 17 Nov 2021: Add support for NFTs

* Feature: Add support for NFTs

# 1.1.2: 22.Sep.2021: Minor bugfix

* Bugfix: Do not count as top holder if the participants list is smallers than 10

# 1.1.1: 23.Jun.2021: Minor bugfix

* Bugfix: Fix a minor issue when there are no winners, a [nil] was returned.

# 1.1.0: 18.Jun.2021: Expose input params for better flexibility

* Expose `#top_n_holders` and `#privileged_never_winning_ratio` on input API

# 1.0.1: 20.May.2021: Expose more output data for stats

* Expose `#top_holders` and `#privileged_participants` (shuffled 10% of users that never won before)

# 1.0.0: 6.May.2021: Initial Release

* Initial release
