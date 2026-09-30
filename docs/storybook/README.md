# From Laptop to Tokyo

*Designing a three-tier system on AWS, one decision at a time.*

A series from the JBC Learning Hub about system thinking. We take one small, real app and move it from a laptop to AWS in Tokyo (`ap-northeast-1`). The aim isn't to teach you Terraform, or even AWS. It's to show how people who design systems think: what they ask first, what they give up, and why.

Writing infrastructure code got cheap. An AI assistant will hand you a working VPC module in a minute. What it can't tell you is whether you need two NAT gateways or none, or what your users see when the database fails over at 3 a.m. That part is still yours, and this series is about that part.

## Who it's for

You can read code and you've seen a web app before. You don't need to know AWS, Docker or networking; every new term is explained the first time it appears.

If you already build on AWS, skip episodes 0 and 1 and use the rest to check your own reasoning. You may disagree with some choices. That's fine, as long as you can say why.

## The story

Zayn wrote Uptime, a small website monitor: you give it a list of URLs, it checks them every minute and tells you which ones are down. It runs on Zayn's laptop in Docker and works fine there.

Then a client asks to run it for real, for users in Japan, on AWS. Zayn knows the code inside out and has never run anything in the cloud. Kian has run AWS systems for years and helps out, mostly by asking awkward questions, and isn't always right. Zayn catches Kian out more than once.

The characters and the client are made up. The app, the numbers and the design are real, and they all live in this repo.

## The episodes

**Part one: know what you're building.** The app and its requirements, before any AWS service is chosen.

| # | Episode | The question | Minutes |
|---|---|---|---|
| 0 | [Design before code](00-prologue.md) | Why design before Terraform? | 8 |
| 1 | [Meet the app](01-meet-the-app.md) | What does Uptime do, and for whom? | 15 |
| 2 | [What good means](02-what-good-means.md) | How many monitors, how much downtime, how much money? | 18 |
| 3 | [The laptop version](03-the-laptop-version.md) | How does it run today, and what does Docker hide from us? | 15 |

**Part two: one domain at a time.** The idea in plain words first, then the AWS answer, the Tokyo price, the options we turned down, and what breaks.

| # | Episode | The question | Minutes |
|---|---|---|---|
| 4 | [Leaving the laptop](04-leaving-the-laptop.md) | Where is the cloud, and who looks after what? | 16 |
| 5 | [Network](05-network.md) | Where does each piece live, and who can reach it? | 20 |
| 6 | [Identity and secrets](06-identity-and-secrets.md) | Who may do what, and where do passwords go? | 18 |
| 7 | [Data](07-data.md) | What happens when the data is deleted, or its machine dies? | 18 |
| 8 | [Compute](08-compute.md) | Where does our code run, and who restarts it? | 18 |
| 9 | [Being found](09-being-found.md) | How does a browser find us, and know it's really us? | 12 |
| 10 | [One door, two rooms](10-one-door-two-rooms.md) | Where does each request go, and who gets turned away? | 18 |
| 11 | [Work on a timer](11-work-on-a-timer.md) | Who runs the check every minute, and what if two run at once? | 16 |
| 12 | [Seeing the system](12-seeing-the-system.md) | How do we find out something broke before the client does? | 17 |
| 13 | [Shipping changes](13-shipping-changes.md) | How does new code reach production with no keys on laptops? | 16 |

**Part three: put it together.**

| # | Episode | The question | Minutes |
|---|---|---|---|
| 14 | [The whole picture](14-the-whole-picture.md) | How do the pieces fit, and what does it cost each month? | 18 |
| 15 | [Epilogue](15-epilogue.md) | What breaks first at 10 times the load, and at 100 times? | 16 |

## How the episodes work

Most episodes open with a short scene and then step out of the story to teach. The idea comes before the AWS name, because the idea outlives the service. Anything that happens in order (a request, a deploy, a failover) is drawn step by step, with every box kept in the same place from frame to frame so you only have to spot what changed.

Every episode ends with three questions to check yourself, most of them small scenarios rather than definitions, and a link to the matching hands-on step if you want to build it.

## How this fits with the rest of the repo

The series explains why. The [step guides](../steps/README.md) and [workbooks](../workbook/README.md) show how, by hand in the console and then in Terraform. Decisions are in the [ADRs](../adr/README.md) and prices in [costs.md](../costs.md). Episodes link to these rather than copying them, so each number is fixed in one place. The hands-on steps have their own numbering (01 to 09), which doesn't match the episode numbers.

Prices were checked in September 2026 and exclude Japan's 10% consumption tax. AWS changes them, so treat them as a guide and check the current price before planning a budget.

The writing rules for the series are in the [voice guide](voice-guide.md).
