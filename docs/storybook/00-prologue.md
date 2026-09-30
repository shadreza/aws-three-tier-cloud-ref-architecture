# Episode 0: Design before code

*From Laptop to Tokyo, part one. About 8 minutes.*

> Zayn had the Terraform open in one window and an AI assistant in the other. In twenty minutes the assistant had written a VPC, three kinds of subnets, a NAT gateway and a database. It all looked right.
>
> "Done," Zayn said. "Want to look before I apply?"
>
> Kian scrolled for a while. "Why two NAT gateways?"
>
> "It said that's best practice."
>
> "Sometimes it is. It's also $98 a month before the app has done a single thing. What happens to your app if there's only one?"
>
> Zayn opened their mouth, then closed it again.
>
> "The code's fine," Kian said. "I just can't tell you if it's the right code. Neither can you, yet. Close the editor for a bit."

## What this series is about

For years, the hard part of putting an app on AWS was the typing. You learned a lot of syntax and a lot of API names before anything worked. Today an assistant writes that code faster than you can read it, and most of the time it runs.

It doesn't make the decisions, though. Every line of infrastructure code carries a choice somebody made: two zones and not three, a database with no route to the internet, a fresh container every minute instead of one that runs forever. If you don't know why a choice was made, you can't tell whether the code in front of you fits your app, and you can't fix it at 3 a.m. when it doesn't.

So this series mostly stays away from code. We follow Zayn, who wrote a small app and has never run anything in the cloud, and Kian, who has run AWS systems for years, as they move that app from a laptop to AWS in Tokyo. We watch the questions they ask and the arguments they have. Kian isn't always right, either. The Terraform for everything is in this repo, and each episode links to the hands-on steps if you want to build along. You won't need them to follow the story.

## What we mean by system thinking

"System thinking" gets used for a lot of things. Here it means five habits, and you'll see all of them in almost every episode.

1. Start from what the app needs, not from the list of services. AWS has more than two hundred of them, and we don't pick one until the app gives us a reason. The first three episodes are about the app and its requirements, before any AWS service gets picked.
2. Draw the boundaries on purpose. Where does each piece live, and who may reach it? Most security problems on AWS come from a boundary nobody drew.
3. Follow one piece of data from the moment it's created to the moment it's deleted. You'll find the parts you forgot.
4. Ask what breaks. Everything fails eventually. What matters is what the user sees when it does, and whether you chose that in advance.
5. Put a price on it. Know what each piece costs per month before you build it.

Under all five is a sixth habit: write down what you didn't choose, and when you'd change your mind. This repo keeps those notes as ADRs (architecture decision records, one short file per decision), and the series quotes them often.

## How it's built

The [series home](README.md) has the full list. In short, part one (episodes 1 to 3) looks at the app on its own. Part two (episodes 4 to 13) takes one domain at a time: network, identity, data, compute, the front door, scheduled work, observability and delivery. Part three (episodes 14 and 15) puts it all on one wall with one monthly bill, and then asks what would change at ten and a hundred times the load.

Most episodes open with a short scene and then leave the story to teach. The idea comes first, in plain words, because the idea outlives the AWS service. Then the AWS answer, the diagrams, the Tokyo price and the options we turned down. Every episode ends with three questions to check yourself, and a link to the matching hands-on step.

## Why Tokyo

Most of the clients this was written for are in Japan, and so are their users. Tokyo (`ap-northeast-1`) is a few milliseconds away from them and keeps the data in the country. It also costs 20 to 30% more than AWS's cheapest region, and episode 4 goes into what the choice really means.

All prices are Tokyo list prices in US dollars, checked in September 2026, without Japan's 10% consumption tax. They come from [costs.md](../costs.md). Prices move, so check them before you plan a real budget.

> "So where do we start?" Zayn asked.
>
> "You tell me what your app does," Kian said. "Properly. As if I'd never seen it."

**Next:** [Episode 1: Meet the app](01-meet-the-app.md)
