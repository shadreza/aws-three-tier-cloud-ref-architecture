# Voice guide

How *From Laptop to Tokyo* should sound. Read this before you write or edit an episode.

## Who we're talking to

One person, sitting down with a coffee, who is smart and new to this. They have time to read but no patience for padding. Explain things the way you would to a colleague you respect.

## The voice

We write as "we": the author and the reader working through it together. "You" is fine when the reader has to do something.

Have opinions. "We picked Fargate" isn't enough; say why, and say what bothers you about it. "Fargate costs more per CPU than EC2, and for a team of two we'd still pay it" is the kind of sentence we want.

Use real numbers. Not "NAT gateways can be expensive" but "the NAT gateway is $49 of our $120 dev bill". Every number has to match `costs.md` or an ADR, and the same number must be the same in every episode.

Admit mistakes and doubts. If a first design was wrong, show it. If a choice is a close call, say so.

Vary the rhythm. Short sentences for the point, longer ones when an idea needs room. Avoid three sentences in a row with the same shape.

Explain every term once, where it first appears, in the sentence itself: "a subnet (a slice of the network's addresses that lives in one zone)". After that, point back to it in a clause instead of explaining it again. Each idea has one home episode; for example the `us-east-1` rule lives in episode 9, `/api/health` versus `/api/ready` in episode 1, "two people, no night shifts" in episode 2, defense in depth in episode 5 (episode 14 applies it to the whole system), and practicing a restore in episode 7.

## The characters

Zayn wrote the app and knows code, not cloud. Zayn's questions are the reader's questions, so they should never sound stupid, and Zayn's knowledge of the code should win arguments regularly: Zayn finds the 1 MB page read (episode 2), spots the migration race (episode 8), corrects Kian on password rotation (episode 6) and on the cost of the scheduler (episode 11), and has the last word in the series.

Kian has done this before and asks good questions. Kian is sometimes wrong and says so: about rotation (episode 6), about alarming on errors (episode 12), about the scheduler's cost (episode 11), and Kian causes the incident in episode 12. Kian doesn't give lectures inside scenes; if a scene needs more than three lines of explanation from one character, move the explanation into the teaching text.

Kian is the senior of the two, and it's fine for him to win more often than he loses, as long as Zayn's knowledge of the code wins the arguments it should. Kian uses he/him. Zayn hasn't been given pronouns, so refer to Zayn by name, or "they" where a pronoun is needed.

## Scenes

Opening scenes are 100 to 250 words, set up the episode's question and get out of the way. A scene can also appear mid-episode when a character discovers something (episodes 2, 6, 8, 11) or when the story jumps in time (episode 12).

Closing scenes are optional and should vary. Don't end every episode with Kian, and don't end every episode on a cliffhanger. Some episodes end with no scene at all.

A little dry humor is fine. Anything that needs a laugh track isn't. If a scene doesn't lead to the episode's question, cut it.

## Structure

The domain episodes share a toolkit, not a template: the idea without AWS names, the AWS answer, diagrams, the Tokyo price, options we turned down, and three check-yourself questions. Change the order when the story is better for it. Episode 7 opens with the disaster, episode 12 opens in the middle of an incident, and episode 11 folds the rejected options into the story.

Write "what we turned down" as a table (option, why not, when we'd switch) or as short plain paragraphs. Don't open paragraphs with a bold label.

Check-yourself questions are scenarios ("the checks stopped on Friday, where do you look?"), not definitions ("what's the difference between X and Y?"). Three per episode.

An episode should take 15 to 20 minutes to read. If it runs longer, split it (that's how episode 9 became episodes 9 and 10).

## Words and patterns we don't use

These make text sound machine-written. Cut them on sight.

- Hype words: robust, seamless, leverage, powerful, cutting-edge, game-changer, unlock, elevate, supercharge.
- AI tells: delve, crucial, pivotal, landscape, tapestry, testament, underscore, showcase, foster, intricate, "plays a key role", "serves as".
- Openers and closers: "In today's world", "Let's dive in", "Here's the thing", "In conclusion", "The future looks bright".
- A neat moral at the end of every section ("Security is mostly design, not spending"). Let the facts land on their own. One such line an episode, at most, and preferably in dialogue.
- Not X but Y: "It's not just a network, it's a security boundary." Say the true thing directly.
- Lists of three by reflex. If there are two reasons, give two.
- "Here's..." as a section opener, and "N things surprise people" lines.
- Em dashes. Use a comma, a colon, a full stop, or brackets.
- Paragraphs or bullets that start with a bold label and a full stop or colon. Bold is for table totals and one thing per section at most.
- Emoji. Title Case In Headings. Curly quotes.
- Vague sources: "experts say", "it is widely known". Name the source or drop the claim.

## Diagrams

- Anything that changes over time (a build-up, a failover, a deploy) is a set of SVG frames built by `docs/diagrams/build.py` (`story-NN-*.svg`). Every box stays in the same place in every frame; new or changed things get a gold ring, things that come later are faded, failures are red. Mermaid can't hold positions between frames, so don't use it for these.
- Maps (where things live) reuse the matching step's SVG. Draw a new one only when no map shows the idea.
- Sequences and simple flows are Mermaid, with the category colors from `CLAUDE.md`.
- A pair-of-boxes-with-an-arrow diagram is a table pretending to be a diagram. Use a table.
- Don't draw the same thing twice in one episode.
- Every diagram has a one-line caption saying what to look at, and the caption must not depend on where Mermaid happens to place things.

## Before an episode is done

- [ ] Every number matches `costs.md`, the ADRs and the other episodes, and every link works.
- [ ] Every new term is explained where it first appears, and ideas explained elsewhere are pointed to, not repeated.
- [ ] Diagrams render (`python3 docs/diagrams/build.py` and `rsvg-convert` for SVG, mermaid-cli for Mermaid), and you've looked at them.
- [ ] Three scenario questions with answers.
- [ ] It went through the humanizer pass and none of the patterns above are left.
- [ ] Read it out loud. Anything you stumble on, rewrite.
