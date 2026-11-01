---
name: asd-ste100
description: >-
  Apply ASD-STE100 clarity principles to English and a mandatory Russian adaptation
  to Russian. Use throughout Doglyad sessions for progress updates, plans,
  questions, explanations, reviews, and final answers. Also use for requested
  technical text rewrites. Preserve meaning, uncertainty, and technical terms.
license: MIT
metadata:
  upstream: https://github.com/danyuchn/asd-ste100-skill
  upstream-commit: c7b11cd9258708909d8574c8176d4c70969c8b29
  upstream-version: "0.4.0"
---

# Clear session communication in Russian and English

Use this skill throughout each Doglyad session, as required by `AGENTS.md`.
It applies to ordinary conversation as well as requested text rewrites.
Use Russian by default. Follow the user's explicit language choice.

## Language and scope

ASD-STE100 defines Simplified Technical English. This skill adapts its clarity
principles for project communication. It does not include the official dictionary
or establish certified compliance.

- For Russian, read [the Russian adaptation](references/russian.md) once before
  composing Russian messages. Its rules are mandatory for this project.
- For English, use the shared rules below and the English guidance in this file.
  Read [the upstream rule summary](references/writing-rules.md) when a detailed
  English rewrite or rule explanation needs it.
- In mixed text, apply each language's rules to its prose. Preserve literal code,
  commands, paths, identifiers, product names, and exact quotations.

These rules control expression. They do not change the user's task, required
response format, project conventions, or authorization. Preserve a requested
creative style in creative deliverables. Use these clarity rules in the
surrounding technical discussion.

## Shared rules

1. Start with the answer, result, or intended action. Include the context needed
   to understand it.
2. Give each sentence one main idea. Give each procedural sentence one
   instruction. Split independent actions into separate sentences or steps.
3. Use active voice when the actor is known and relevant. Name the actor when
   omitting it would make responsibility unclear. Never invent an unknown actor.
4. Use direct verbs and familiar words. Replace phrases such as "perform an
   analysis" with "analyze" when the meaning stays the same.
5. Use the same term for the same concept. Preserve distinctions between
   different concepts. Define an unfamiliar technical term when needed.
6. Make conditions and their consequences explicit. Preserve the scope of
   "only", "unless", "before", "after", and negation.
7. Preserve every relevant fact, exception, number, unit, and requirement.
   Keep the original strength of obligations, permissions, and uncertainty.
   "May fail" must not become "fails". "Must" must not become "can".
8. Distinguish plans, actions in progress, completed actions, and verified results.
   Report what a check established. State material limits of that check.
9. Keep one topic per paragraph, with no more than six sentences. Use numbered
   lists for ordered steps and bullets for parallel items when they help reading.
10. Remove filler, repeated conclusions, unsupported praise, metaphors, and
    unnecessary jargon. Keep reasons, evidence, and qualifications that matter.

For English, use at most 20 words per procedural sentence and 25 per descriptive
sentence where meaning can be preserved. For Russian, use these as editing
targets under the Russian adaptation. Preserve necessary precision if a sentence
must be longer. Do not compress prose into fragments or remove facts to meet a
word count.

## English guidance

- Prefer simple present, past, future, or imperative forms. Keep a compound
  form when it carries necessary timing or uncertainty, such as "may have failed".
- Replace phrasal verbs with a direct equivalent when the meaning stays the same:
  "start" instead of "spin up".
- Split noun clusters longer than three words with prepositions or a new sentence.
  Preserve established technical names.
- Keep necessary subjects, verbs, articles, and connecting words.
- Replace semicolons in prose with separate sentences or a suitable list.
- Use plain, consistent vocabulary. Do not claim that words were checked against
  the official ASD dictionary unless that check actually occurred.

These English grammar rules do not define Russian grammar.

## Apply the skill

Before sending a message, check its meaning and wording internally:

1. Check the response language and the applicable language guidance.
2. Check that the main point, actor, action, and conditions are clear.
3. Split overloaded sentences and replace unnecessary complexity.
4. Compare the result with the intended meaning. Check uncertainty, obligations,
   negation, numbers, exceptions, and technical terms.
5. Keep enough context for the user to understand the result and any next action.

Do not print a rule audit or a compliance claim in routine messages.
No external tool or linter is required for each response. English-only lint
results do not validate Russian grammar, vocabulary, or meaning.

## Output

For ordinary work, provide the requested progress updates, explanations,
verification results, and final answer in this style. Do not reduce a coding
task to a text rewrite or omit its results.

For an explicit text rewrite, return the rewritten text by default. Add a brief
note only when a material ambiguity or necessary exception needs explanation.
When requested, show a before/after comparison and explain the relevant rules.
Use the user's language for those explanations.

## Source

Adapted from [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill/tree/c7b11cd9258708909d8574c8176d4c70969c8b29),
upstream version 0.4.0. The [MIT license](LICENSE) retains the author's notice.
The upstream English rule summary is included unchanged.
The session workflow and Russian adaptation are Doglyad additions.

The [official ASD-STE100 overview](https://www.asd-ste100.org/about_STE.html)
describes the English writing rules and controlled dictionary.
