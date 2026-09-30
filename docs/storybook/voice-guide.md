# Voice guide

How *From Laptop to Tokyo* should sound. Read this before you write or edit an episode.

## Who we're talking to

One person, sitting down with a coffee, who is smart and new to this. They have time to read, but not patience for padding. Talk to them the way you'd explain something to a colleague you respect.

## The voice

We write as "we": the author and the reader working through it together. "You" is fine when the reader has to do something.

**Have opinions.** "We picked Fargate" isn't enough. Say why, and say what bothers you about it. "Fargate costs more per CPU than EC2, and for a team of two we'd still pay it" is the kind of sentence we want.

**Use real numbers.** Not "NAT gateways can be expensive" but "the NAT gateway is $49 of our $120 dev bill, and it does nothing but let containers reach the internet." Every number has to match `costs.md` or an ADR.

**Admit mistakes and doubts.** If the first design was wrong, show it and show why. If a choice is a close call, say so. Readers trust someone who admits a close call.

**Vary the rhythm.** Short sentences for the point. Longer ones when an idea needs room to unfold. Avoid three sentences in a row with the same shape.

**Explain every term once, where it first appears.** In plain words, right in the sentence: "a subnet (a slice of the network's addresses that lives in one zone)". Don't gather definitions into a glossary box.

## The story parts

The opening scene is short: 100 to 250 words. It sets up the question and then gets out of the way.

Zayn wrote the app and knows code, but not cloud. Zayn's questions are the reader's questions, so they should never sound stupid. Kian has done this before, answers questions with questions, and is sometimes wrong. Nobody gives lectures inside a scene. Refer to both by name; we haven't given either of them pronouns, so where one is needed, use "they".

No jokes that need a laugh track. A little dry humor is fine. If a scene doesn't lead to the episode's question, cut it.

## Words and patterns we don't use

These make text sound machine-written. Cut them on sight.

- Hype words: robust, seamless, leverage, powerful, cutting-edge, game-changer, unlock, elevate, supercharge.
- AI tells: delve, crucial, pivotal, landscape, tapestry, testament, underscore, showcase, foster, intricate, "plays a key role", "serves as".
- Openers and closers: "In today's world", "Let's dive in", "In conclusion", "The future looks bright", "Happy building!".
- Not X but Y: "It's not just a network, it's a security boundary." Say the true thing directly.
- Lists of three by reflex. If there are two reasons, give two.
- Em dashes. Use a comma, a colon, full stop, or brackets.
- Bullet lists where every item starts with a bold label and a colon. Write a paragraph or a table instead.
- Bold scattered through paragraphs. Bold one thing per section at most, the thing the reader must not miss.
- Emoji. Title Case In Headings. Curly quotes.
- Vague sources: "experts say", "it is widely known". Name the source or drop the claim.

## Diagrams

Every idea that has a shape gets a picture.

- The **map** (where things live) is an SVG built by `docs/diagrams/build.py`, in the style described in `CLAUDE.md`. Each domain episode reuses the map of the matching step (`aws-network.svg`, `step-03-data.svg` and so on), so there is one picture per layer to keep up to date. Draw a new SVG only when no existing map shows the idea.
- **Flows** (anything that moves in order) are Mermaid sequence diagrams or flowcharts with the category colors from `CLAUDE.md`.
- If a flow has more than about seven steps or shows a change over time (build-up, failover, deploy), split it into **frames**: "Frame 1: ...", "Frame 2: ...", with one sentence under each saying what changed.
- Every diagram has a one-line caption saying what to look at.

## Before an episode is done

- [ ] It follows the episode shape in the [series README](README.md#how-every-episode-works).
- [ ] Every number matches `costs.md` or an ADR, and every link works.
- [ ] Every new term is explained where it first appears.
- [ ] Diagrams render (`rsvg-convert` for SVG, mermaid-cli for Mermaid).
- [ ] It went through the humanizer pass and none of the patterns above are left.
- [ ] Read it out loud. Anything you stumble on, rewrite.
