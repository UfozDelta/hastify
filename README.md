<p align="center"><img src="assets/hastify.svg" alt="Hastify" width="640"></p>

Home Screen widget + app that tracks your in-person Apple Pay spending. Free, sideloaded, built without a Mac.

**How it works:** Wallet tap → Shortcuts *Transaction* automation → **Log Spend** App Intent → shared JSON → widget updates.

**Features:** today / yesterday / week / month totals, daily average, 7/30-day chart, spend by merchant, tap history, manual entry.

**Build:** push to `main`; GitHub Actions builds `Hastify.ipa` (XcodeGen + xcodebuild). Install with SideStore.

**Setup:** Shortcuts → Automation → Transaction → Run Immediately → *Log Spend* (Amount / Merchant / Card from input). Then add the widget.

Status and roadmap: [PLAN.md](PLAN.md)
