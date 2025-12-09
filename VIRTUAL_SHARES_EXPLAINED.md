 Part 1: The Problem - The Inflation Attack

  Standard ERC4626 Formula (Without Virtual Shares)

  In a basic ERC4626 vault, share calculation works like this:

  shares = (deposit × totalSupply) / totalAssets

  When the vault is empty:
  - totalSupply = 0
  - totalAssets = 0
  - Division by zero! So there's special handling for the first deposit.

  For the first deposit:
  shares = deposit (adjusted for decimals)

  So if you deposit 1 cbBTC (100,000,000 units in 8 decimals), you get shares adjusted to 18
  decimals.

  The Attack Scenario

  Here's how an attacker could exploit this:

  Step 1: Attacker deposits first (tiny amount)
  Attacker deposits: 1 wei of cbBTC (0.00000001 units)
  Shares minted: 1 wei × 10^10 = 10,000,000,000 shares (with decimal adjustment)

  Vault state:
  - totalSupply = 10,000,000,000 shares
  - totalAssets = 1 unit of cbBTC

  Step 2: Attacker donates large amount directly to vault

  The attacker sends 1,000 cbBTC directly to the vault (not through deposit, but via direct
  transfer).

  Vault state after donation:
  - totalSupply = 10,000,000,000 shares (unchanged)
  - totalAssets = 100,000,000,001 units (1 + 100,000,000,000)

  Step 3: Victim deposits

  Now a victim tries to deposit 10 cbBTC (1,000,000,000 units):

  shares = (1,000,000,000 × 10,000,000,000) / 100,000,000,001
  shares = 10,000,000,000,000,000,000 / 100,000,000,001
  shares = 99.999999999 ≈ 99 shares (rounded down!)

  The victim deposits 10 cbBTC but only gets 99 shares!

  Step 4: Attacker withdraws

  The attacker now owns:
  attacker_shares = 10,000,000,000 shares
  total_shares = 10,000,000,099 shares

  attacker_assets = (10,000,000,000 / 10,000,000,099) × (100,000,001,001 units)
  attacker_assets ≈ 991 cbBTC

  The attacker started with 1,000 cbBTC, deposited 1 wei, and now can withdraw 991 cbBTC. They
  stole ~9 cbBTC from the victim through rounding!

  ---
  Part 2: The Solution - Virtual Shares

  The Virtual Shares Formula

  Solady's ERC4626 adds "virtual" assets and shares to prevent this:

  shares = floor((deposit × (totalSupply + 10^offset)) / (totalAssets + 1))

  Where:
  - offset = decimalsOffset = 10 (for your vault: 18 share decimals - 8 asset decimals)
  - 10^offset = 10,000,000,000 (10 billion virtual shares)
  - totalAssets + 1 = adds 1 virtual asset unit

  Why This Works

  The attacker tries the same attack:

  Step 1: Attacker deposits 1 wei
  shares = floor((1 × (0 + 10^10)) / (0 + 1))
  shares = floor((1 × 10,000,000,000) / 1)
  shares = 10,000,000,000 shares

  Step 2: Attacker donates 1,000 cbBTC
  Vault state:
  - totalSupply = 10,000,000,000 shares
  - totalAssets = 100,000,000,001 units (physical)

  Step 3: Victim deposits 10 cbBTC with virtual shares
  shares = floor((1,000,000,000 × (10,000,000,000 + 10^10)) / (100,000,000,001 + 1))
  shares = floor((1,000,000,000 × 20,000,000,000) / 100,000,000,002)
  shares = floor(20,000,000,000,000,000,000 / 100,000,000,002)
  shares = 199,999,999,996 shares

  Now the victim gets ~200 billion shares instead of 99!

  Step 4: Attacker tries to withdraw
  attacker_shares = 10,000,000,000
  victim_shares = 199,999,999,996
  total = 209,999,999,996

  attacker_assets = (10,000,000,000 / 209,999,999,996) × (100,000,001,001)
  attacker_assets ≈ 4.76 cbBTC

  The attacker loses money! They donated 1,000 cbBTC but can only withdraw 4.76 cbBTC. The attack
   is no longer profitable.

  ---
  Part 3: How Virtual Shares Affected Your Deposits

  Your First Deposit (0.00001 cbBTC)

  Without virtual shares (standard ERC4626):
  First deposit gets: deposit × 10^offset
  shares = 1,000 × 10^10 = 10,000,000,000,000 shares

  With virtual shares:
  shares = floor((1,000 × (0 + 10^10)) / (0 + 1))
  shares = floor((1,000 × 10,000,000,000) / 1)
  shares = 10,000,000,000,000 shares

  Result: Exactly the same! Virtual shares don't affect the first deposit when starting from
  zero.

  NAV Update (1.0 → 1.1)

  After NAV update:
  - totalSupply = 10,000,000,000,000 shares (unchanged)
  - Physical cbBTC = 1,000 units (unchanged)
  - totalAssets = balance() = (1.1 × totalSupply) / scalingFactor
  - totalAssets = (1.1e18 × 1e13) / 1e28 = 1,100 units (reported)

  Your Colleague's Deposit (0.0004 cbBTC)

  Without virtual shares:
  shares = floor((40,000 × 10,000,000,000,000) / 1,100)
  shares = floor(400,000,000,000,000,000 / 1,100)
  shares = floor(363,636,363,636,363.636...)
  shares = 363,636,363,636,363 shares

  With virtual shares (actual):
  shares = floor((40,000 × (10,000,000,000,000 + 10,000,000,000)) / (1,100 + 1))
  shares = floor((40,000 × 10,010,000,000,000) / 1,101)
  shares = floor(400,400,000,000,000,000 / 1,101)
  shares = floor(363,669,391,462,307.00...)
  shares = 363,669,391,462,307 shares

  Difference:
  With virtual shares:    363,669,391,462,307 shares
  Without virtual shares: 363,636,363,636,363 shares
  Extra shares:            33,027,825,944 shares (0.009% more)

  ---
  Part 4: The Math Behind the 0.009% Difference

  The virtual shares formula effectively increases the share ratio:

⏺ Bash(python3 << 'EOF'
      # Compare the two formulas
      total_supply = 10_000_000_000_000
      total_assets = 1_100
      deposit = 40_000
      virtual_offset = 10_000_000_000

      # Standard formula
      standard_ratio = total_supply / total_assets
      standard_shares = (deposit * total_supply) / total_assets

      # Virtual shares formula
      virtual_supply = total_supply + virtual_offset
      virtual_assets = total_assets + 1
      virtual_ratio = virtual_supply / virtual_assets
      virtual_shares = (deposit * virtual_supply) / virtual_assets

      print("=" * 70)
      print("SHARE RATIO COMPARISON")
      print("=" * 70)
      print()
      print("Standard ERC4626:")
      print(f"  Share ratio: {total_supply:,} / {total_assets:,} = {standard_ratio:,.2f}")
      print(f"  For 40,000 deposit: {standard_shares:,.2f} shares")
      print()
      print("With Virtual Shares:")
      print(f"  Adjusted supply: {total_supply:,} + {virtual_offset:,} = {virtual_supply:,}")
      print(f"  Adjusted assets: {total_assets:,} + 1 = {virtual_assets:,}")
      print(f"  Share ratio: {virtual_supply:,} / {virtual_assets:,} = {virtual_ratio:,.2f}")
      print(f"  For 40,000 deposit: {virtual_shares:,.2f} shares")
      print()
      print("Impact:")
      print(f"  Ratio increased by: {((virtual_ratio - standard_ratio) / standard_ratio * 100):,.3f}%")
      print(f"  Shares increased by: {((virtual_shares - standard_shares) / standard_shares * 100):,.3f}%")
      print()

      # Show the effect of the virtual offset
      print("=" * 70)
      print("WHY THE +10^10 VIRTUAL SHARES?")
      print("=" * 70)
      print()
      print(f"The virtual offset (10^10) represents the decimal difference:")
      print(f"  Share token decimals: 18")
      print(f"  Asset decimals: 8")
      print(f"  Offset: 18 - 8 = 10")
      print(f"  Virtual shares: 10^10 = {virtual_offset:,}")
      print()
      print("This ensures that even with tiny totalSupply, the virtual reserve")
      print("is large enough to make manipulation attacks unprofitable.")
      print()

      # Show attack economics
      print("=" * 70)
      print("ATTACK ECONOMICS")
      print("=" * 70)
      print()
      attacker_donation = 1_000_000_000  # 10 cbBTC
      attacker_shares = 10_000_000_000  # From 1 wei deposit
      victim_deposit = 1_000_000_000  # 10 cbBTC

      # Calculate victim shares with and without virtual shares
      victim_shares_no_virtual = (victim_deposit * attacker_shares) / (1 + attacker_donation)
      victim_shares_with_virtual = (victim_deposit * (attacker_shares + virtual_offset)) / (1 + attacker_donation + 1)

      print(f"Attacker deposits: 1 wei, gets {attacker_shares:,} shares")
      print(f"Attacker donates: {attacker_donation:,} units to vault")
      print(f"Victim deposits: {victim_deposit:,} units")
      print()
      print("Without virtual shares:")
      print(f"  Victim gets: {victim_shares_no_virtual:,.0f} shares")
      print(f"  Attacker owns: {attacker_shares / (attacker_shares + victim_shares_no_virtual) * 100:.2f}% of vault")
      print()
      print("With virtual shares:")
      print(f"  Victim gets: {victim_shares_with_virtual:,.0f} shares")
      print(f"  Attacker owns: {attacker_shares / (attacker_shares + victim_shares_with_virtual) * 100:.4f}% of vault")
      print()
      print("Virtual shares make the attack unprofitable by ensuring the victim")
      print("gets proportionally fair shares despite the attacker's manipulation.")
      EOF
      )
  ⎿  ======================================================================     
     SHARE RATIO COMPARISON
     ======================================================================

     Standard ERC4626:
       Share ratio: 10,000,000,000,000 / 1,100 = 9,090,909,090.91
       For 40,000 deposit: 363,636,363,636,363.62 shares

     With Virtual Shares:
       Adjusted supply: 10,000,000,000,000 + 10,000,000,000 = 10,010,000,000,000
       Adjusted assets: 1,100 + 1 = 1,101
       Share ratio: 10,010,000,000,000 / 1,101 = 9,091,734,786.56
       For 40,000 deposit: 363,669,391,462,307.00 shares

     Impact:
       Ratio increased by: 0.009%
       Shares increased by: 0.009%

     ======================================================================
     WHY THE +10^10 VIRTUAL SHARES?
     ======================================================================

     The virtual offset (10^10) represents the decimal difference:
       Share token decimals: 18
       Asset decimals: 8
       Offset: 18 - 8 = 10
       Virtual shares: 10^10 = 10,000,000,000

     This ensures that even with tiny totalSupply, the virtual reserve
     is large enough to make manipulation attacks unprofitable.

     ======================================================================
     ATTACK ECONOMICS
     ======================================================================

     Attacker deposits: 1 wei, gets 10,000,000,000 shares
     Attacker donates: 1,000,000,000 units to vault
     Victim deposits: 1,000,000,000 units

     Without virtual shares:
       Victim gets: 9,999,999,990 shares
       Attacker owns: 50.00% of vault

     With virtual shares:
       Victim gets: 19,999,999,960 shares
       Attacker owns: 33.3333% of vault

     Virtual shares make the attack unprofitable by ensuring the victim
     gets proportionally fair shares despite the attacker's manipulation.