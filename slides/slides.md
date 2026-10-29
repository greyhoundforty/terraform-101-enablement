---
theme: default
title: Infrastructure as Code on IBM Cloud
info: |
  IaC lunch and learn, session 1: Terraform fundamentals.
  Sections 1-4: the problem, what Terraform is, repeatability, state.
author: Ryan Tiffany
colorSchema: light
aspectRatio: 16/9
transition: fade
mdc: true
layout: carbon-cover
fonts:
  sans: IBM Plex Sans
  mono: IBM Plex Mono
  weights: '300,400,500,600'
  provider: google
drawings:
  persist: false
---

<p class="kicker">Lunch and learn · Session 1 of the IaC series</p>

# Infrastructure as Code on IBM Cloud

<p class="cover-sub">Terraform fundamentals: repeatability, state and auditability</p>

<Pipeline :active="0" />

<p class="presenter">Ryan Tiffany · IBM Brand Technical Specialist</p>

<!--
Welcome. 45 minutes: 25 to 30 of slides and questions, then a 10 to 15 minute live demo where we stand up a VPC and a server, change it, plan and apply.

Rough pacing for the talk: problem 3-4 min, what Terraform is 4-5, repeatability 5, state 7-8, auditability 4-5, road ahead and recap 3.

This is session 1 of a series. Today is the foundation (Terraform). Each later session answers the pain left by the one before: Schematics, then Deployable Architectures, then Projects.
-->

---

<p class="kicker">Today</p>

# Three ideas for today

<div class="tiles c3">
  <div class="tile" v-click>
    <carbon-copy />
    <h3>Repeatability</h3>
    <p>The same code gives the same environment, every time.</p>
  </div>
  <div class="tile purple" v-click>
    <carbon-data-base />
    <h3>State is the source of truth</h3>
    <p>Terraform remembers what it built, so it knows what to change.</p>
  </div>
  <div class="tile green" v-click>
    <carbon-version />
    <h3>Auditability</h3>
    <p>Version control shows what changed, who changed it and when.</p>
  </div>
</div>

<p class="takeaway" v-click>Then a live demo: VPC and server, one change, plan, apply.</p>

<!--
[click] Repeatability: same code, same result.
[click] State: the file that makes Terraform work, and the one new idea for most of you.
[click] Auditability: you can prove what changed.
[click] Then we do it live. No background in Terraform needed.
-->

---

<p class="kicker"><b>1</b> · The problem</p>

<p class="hero">“Build me the <em>same</em> POC environment. Again.”</p>

<p class="lede" v-click>Raise your hand if you have built a POC in the portal. Keep it up if you have built the same one twice.</p>

<!--
Open with the question and wait for hands.

Most people who have built a POC have rebuilt one. That is the problem this whole series is about.
-->

---

<p class="kicker"><b>1</b> · The problem</p>

# Here is what that looks like in the portal

<div class="steps">
  <span class="step" v-click><i>1</i> Create VPC</span>
  <span class="step" v-click><i>2</i> Pick region</span>
  <span class="step" v-click><i>3</i> Create subnet</span>
  <span class="step" v-click><i>4</i> Pick zone</span>
  <span class="step" v-click><i>5</i> Create SSH key</span>
  <span class="step" v-click><i>6</i> Create server</span>
  <span class="step" v-click><i>7</i> Pick image and profile</span>
  <span class="step" v-click><i>8</i> Attach subnet</span>
  <span class="step" v-click><i>9</i> Reserve floating IP</span>
</div>

<p class="takeaway" v-click><strong>20+ clicks, and the order matters.</strong></p>

<!--
Say the steps out loud as each one appears. Do not rush it; the length is the point.

[click x9] one per step.
[click] That is more than 20 clicks, and if you create the subnet before the VPC, it fails.
-->

---

<p class="kicker"><b>1</b> · The problem</p>

# The second build never matches the first

<div class="tiles c3">
  <div class="tile red" v-click>
    <carbon-warning-alt />
    <h3>It drifts</h3>
    <p>A different profile, a missed setting, a different zone.</p>
  </div>
  <div class="tile red" v-click>
    <carbon-edit-off />
    <h3>Nobody wrote it down</h3>
    <p>The clicks lived in one person’s head.</p>
  </div>
  <div class="tile red" v-click>
    <carbon-document />
    <h3>The record is a screenshot</h3>
    <p>“What did you deploy?” gets a PNG, not an answer.</p>
  </div>
</div>

<p class="takeaway" v-click>What if you told IBM Cloud <strong>what</strong> you want, not <strong>how</strong>?</p>

<!--
[click] Drift and snowflakes: every environment ends up slightly different.
[click] Nobody remembers what was clicked.
[click] When the customer asks what you deployed, the answer is a screenshot.
[click] Transition: instead of telling IBM Cloud how, just tell it what you want.
-->

---

<p class="kicker"><b>2</b> · What Terraform is</p>

<p class="hero wide">Declarative: describe the <span class="nowrap" v-mark.blue.underline="1">end state</span>, not the <span v-mark.red.strike-through="2">steps</span>.</p>

<p class="lede" v-click="2">Say “I want a VPC.” Terraform works out how.</p>

<!--
This is the key line of the whole talk. Leave it on screen for a moment.

[click] End state underlined: the result you want.
[click] Steps crossed out: you stop being the orchestrator.
-->

---

<p class="kicker"><b>2</b> · What Terraform is</p>

# Portal versus Terraform

<div class="cols">
  <div class="col">
    <div class="col-head"><h3>Portal</h3><span class="tag">Imperative</span></div>
    <ul class="imperative">
      <li v-click>“Create a VPC.”</li>
      <li v-click>“Now create a subnet in it.”</li>
      <li v-click>“Now create a server.”</li>
      <li v-click>“Now attach…”</li>
    </ul>
    <p class="dim small" v-click>You are the orchestrator. You track what is done.</p>
  </div>
  <div class="col">
    <div class="col-head"><h3>Terraform</h3><span class="tag blue">Declarative</span></div>

```hcl
resource "ibm_is_vpc" "main" { … }

resource "ibm_is_subnet" "main" {
  vpc = ibm_is_vpc.main.id
}

resource "ibm_is_instance" "vsi" {
  vpc = ibm_is_vpc.main.id
}
```

<p class="dim small">“A VPC, with a subnet, with a server in it.” Terraform works out the order and the dependencies.</p>
  </div>
</div>

<!--
Left side: read each instruction in a bored, step-by-step voice. [click x4]. You track what is done.

Right side: you describe the result. You never say "first, then". Terraform sees that the subnet refers to the VPC, so it builds the VPC first.

Analogy for the next slide: turn-by-turn directions versus a blueprint.
-->

---

<p class="kicker"><b>2</b> · What Terraform is</p>

# Directions or a blueprint

<div class="cols">
  <div class="tile" v-click>
    <carbon-rule />
    <h3>A contractor with verbal instructions</h3>
    <p>Every build depends on who is listening, and on what they remember.</p>
  </div>
  <div class="tile purple-bg" v-click>
    <carbon-document />
    <h3>A contractor with the blueprint</h3>
    <p>The same house, every time. Hand them the blueprint twice and they build one house.</p>
  </div>
</div>

<p class="takeaway" v-click><strong>Run it twice and the second run does nothing</strong>, because the end state is already true. Click “create” twice in the portal and you get two VPCs.</p>

<!--
[click] Verbal instructions: turn-by-turn directions.
[click] Blueprint: you describe the end result, and the contractor checks what already exists.
[click] The bonus point: the second run does nothing. I will show this in the demo when apply says "No changes".
-->

---

<p class="kicker"><b>2</b> · What Terraform is</p>

# Four words are all you need today

<div class="cols wide-left">
  <div>

```hcl {*|1-3|9-13|5-7|15-17}
provider "ibm" {
  region = var.region
}

variable "vsi_profile" {
  default = "bx2-2x8"
}

resource "ibm_is_instance" "vsi" {
  name    = "${var.name_prefix}-vsi"
  profile = var.vsi_profile
  # image, subnet, keys ...
}

output "vsi_id" {
  value = ibm_is_instance.vsi.id
}
```

  </div>
  <div class="vocab">
    <div class="term-row" :class="{ on: $clicks === 1 }"><b>provider</b><span>Who we talk to</span></div>
    <div class="term-row" :class="{ on: $clicks === 2 }"><b>resource</b><span>The thing we want</span></div>
    <div class="term-row" :class="{ on: $clicks === 3 }"><b>variable</b><span>The knobs</span></div>
    <div class="term-row" :class="{ on: $clicks === 4 }"><b>output</b><span>What we get back</span></div>
  </div>
</div>

<!--
Do not teach syntax. Match each word to a block of code.

[click] provider: IBM Cloud, in this region.
[click] resource: the server we want.
[click] variable: the knobs. Change the value, not the code.
[click] output: what we get back when it is built.

Declarative is what makes the next three ideas possible: repeatability, state and audit.
-->

---

<p class="kicker"><b>3</b> · Repeatability</p>

<p class="hero wide">Same file. Same result. <em>Every time.</em></p>

<p class="lede" v-click>Remember the 20+ clicks? Here is the same environment as a text file.</p>

<!--
Callback to the 20+ clicks from the start of the talk.
-->

---

<p class="kicker"><b>3</b> · Repeatability</p>

# Change the inputs, not the code

<div class="bigcode">

```hcl
variable "region"      { default = "us-south" }
variable "zone"        { default = "us-south-1" }
variable "name_prefix" { default = "ll-demo" }
variable "vsi_profile" { default = "bx2-2x8" }
```

</div>

<p class="dim" style="margin-top:22px">Four knobs. Everything else in the code stays the same.</p>

<p class="takeaway" v-click>Next: three environments from <strong>one</strong> codebase.</p>

<!--
Show the idea, not the syntax. Four variables: region, zone, name prefix, server profile.

The point: the code does not change between environments. Only the values do.
-->

---

<p class="kicker"><b>3</b> · Repeatability</p>

# One codebase, three environments

<div class="tiles c3">
  <div v-click>
    <div class="code-label">Dev</div>

```hcl
name_prefix = "dev"
vsi_profile = "bx2-2x8"
zone        = "us-south-1"
```

  </div>
  <div v-click>
    <div class="code-label">Test</div>

```hcl
name_prefix = "test"
vsi_profile = "bx2-2x8"
zone        = "us-south-2"
```

  </div>
  <div v-click>
    <div class="code-label">Customer POC</div>

```hcl
name_prefix = "acme-poc"
vsi_profile = "bx2-4x16"
zone        = "us-south-1"
```

  </div>
</div>

<p class="takeaway" v-click>Only the values change. Everything else is identical.</p>

<!--
[click] Dev: small profile, one zone.
[click] Test: same code, different prefix.
[click] Customer POC: same code, the customer's name as the prefix.
[click] Only the values change.

Demo callback: change name_prefix and show plan proposing a completely new set of resources from the same code.
-->

---

<p class="kicker"><b>3</b> · Repeatability</p>

# Modules: write it once, call it anywhere

<div class="bigcode">

```hcl
module "network" {
  source      = "./modules/vpc-with-subnets"
  name_prefix = var.name_prefix
  region      = var.region
}
```

</div>

<p style="margin-top:22px">A module is a reusable chunk of Terraform.</p>

<p class="takeaway" v-click>This is the bridge to <strong>Deployable Architectures</strong>, later in the series.</p>

<!--
One sentence only: a module is a reusable chunk. Write "a VPC with subnets" once, and call it from anywhere.

Do not go deeper. If you are running long, cut this slide.

[click] Modules are the bridge to Deployable Architectures.
-->

---

<p class="kicker"><b>3</b> · Repeatability</p>

# Why this matters when you sell

<div class="tiles c3">
  <div class="tile" v-click>
    <carbon-flash />
    <h3>Faster POCs</h3>
    <p>Hours of portal work becomes minutes.</p>
  </div>
  <div class="tile" v-click>
    <carbon-checkmark-outline />
    <h3>Consistent customer environments</h3>
    <p>No “it worked on my POC” surprises.</p>
  </div>
  <div class="tile" v-click>
    <carbon-cube />
    <h3>Reusable patterns</h3>
    <p>Your best architecture becomes a repo, not a slide.</p>
  </div>
</div>

<p class="takeaway" v-click>Repeatable only works if Terraform knows what it already built.</p>

<!--
Say these three out loud; they are the seller takeaways.

[click] Faster POCs.
[click] Consistent customer environments.
[click] Reusable patterns.
[click] Transition: repeatable only works if Terraform knows what it already built. That is the next idea, and it is the big one.
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

<p class="hero wide">“I want a VPC.” Does it already exist?</p>

<ul class="lede" style="list-style:none;padding:0">
  <li v-click>Did I make it?</li>
  <li v-click>Which one is it?</li>
</ul>

<p class="takeaway" v-click>Terraform cannot just look at the cloud and guess.</p>

<!--
Take this section slowly. It is the concept least familiar to this audience.

[click] Did I make it?
[click] Which one is it?
[click] Terraform cannot look at the cloud and guess which VPC is "mine".
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

# The state file is Terraform’s memory

<div class="cols wide-left">
  <div class="compact">

```json {*|3-4|7|9}
{
  "resources": [{
    "type": "ibm_is_instance",
    "name": "vsi",
    "instances": [{
      "attributes": {
        "id": "0717_8e51…",
        "name": "ll-demo-vsi",
        "profile": "bx2-2x8"
      }
    }]
  }]
}
```

  </div>
  <div class="vocab">
    <div class="term-row" :class="{ on: $clicks === 1 }"><b>Your code</b><span>This is the thing named vsi in main.tf</span></div>
    <div class="term-row" :class="{ on: $clicks === 2 }"><b>The real thing</b><span>…and this is its ID in IBM Cloud</span></div>
    <div class="term-row" :class="{ on: $clicks === 3 }"><b>What it looked like</b><span>The last values Terraform recorded</span></div>
  </div>
</div>

<!--
Trimmed example; a real state file holds every attribute of every resource. A JSON file that maps each thing in your code to the real resource ID in IBM Cloud.

[click] The type and name from your code.
[click] The real ID in IBM Cloud. Highlight this one.
[click] The values Terraform last recorded.

Do not cat the whole state file on screen. It can contain sensitive values.
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

# See it for real

<div class="cols" style="grid-template-columns:minmax(0,.8fr) minmax(0,1.5fr);gap:24px;align-items:start">
<pre class="term md" v-click><span class="dim">$ terraform state list</span>
ibm_is_instance.vsi
ibm_is_ssh_key.main
ibm_is_subnet.main
ibm_is_vpc.main</pre>
<pre class="term md" v-click><span class="dim">$ terraform state show ibm_is_instance.vsi</span>
# ibm_is_instance.vsi:
resource "ibm_is_instance" "vsi" {
    id      = "0717_8e51…"
    name    = "ll-demo-vsi"
    profile = "bx2-2x8"
    # … trimmed
}</pre>
</div>

<p class="takeaway" v-click>The ID in state is how Terraform finds the real server.</p>

<!--
This is the same state file, read through two safe commands. It is also what you will run in the demo.

[click] state list: every resource Terraform is tracking, by its name in the code. Four resources, four lines.
[click] state show: one resource, with the real ID and the recorded values. Compare it with the JSON from two slides ago.
[click] The ID is the link between the name in your code and the real server in IBM Cloud.

Why use these instead of opening the file: state show hides values marked sensitive, so it is safe to put on a screen. They are still stored in the state file itself, which is why the file needs protecting.
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

# The loop: write, plan, apply

<div class="flow">
  <div class="stage" v-click>
    <div class="cmd">write</div>
    <div class="what">Describe the end state.</div>
    <div class="rw"><b>Changes:</b> your code</div>
  </div>
  <div class="stage" v-click>
    <div class="cmd">plan</div>
    <div class="what">Show the difference. Change nothing.</div>
    <div class="rw"><b>Reads:</b> code, state, cloud<br><b>Writes:</b> nothing</div>
  </div>
  <div class="stage" v-click>
    <div class="cmd">apply</div>
    <div class="what">Make only that difference.</div>
    <div class="rw"><b>Reads:</b> code, state, cloud<br><b>Writes:</b> cloud, then state</div>
  </div>
</div>

<p class="takeaway" v-click>Run <code>init</code> once to download the provider. Then repeat the loop.</p>

<!--
Put this on one slide: write, plan, apply.

[click] write: describe the end state.
[click] plan: Terraform compares and shows the difference. Nothing changes. This is the safe step.
[click] apply: executes only that difference, then updates state.
[click] Init runs once to download the IBM Cloud provider; then it is the loop.

The interactive State Loop page walks through this with the desired and current state highlighted.
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

# Plan compares three things

<div class="legend"><span><i class="d"></i>Desired</span><span><i class="c"></i>Current</span></div>

<div class="triad">
  <div class="node desired" v-click>
    <div class="lbl">Desired</div>
    <div class="nm">Your code</div>
    <div class="sub">What you want</div>
    <div class="val">profile = "bx2-4x16"</div>
  </div>
  <div class="node current" v-click>
    <div class="lbl">Current · recorded</div>
    <div class="nm">State file</div>
    <div class="sub">What Terraform remembers</div>
    <div class="val gap">profile = "bx2-2x8"</div>
  </div>
  <div class="node current" v-click>
    <div class="lbl">Current · actual</div>
    <div class="nm">IBM Cloud</div>
    <div class="sub">What really exists</div>
    <div class="val gap">profile = "bx2-2x8"</div>
  </div>
</div>

<p class="verdict" v-click><b>Plan:</b> change the server from <code>bx2-2x8</code> to <code>bx2-4x16</code>. Nothing else.</p>

<!--
Desired is blue; current is purple. Keep the colors consistent with the interactive page.

[click] Desired: your code, what you want.
[click] Recorded: the state file, what Terraform remembers.
[click] Actual: what really exists in IBM Cloud.
[click] The plan is the difference between desired and current. Only the server changes.

Plan is also a drift detector: if someone changes something in the portal, plan reveals it.
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

# Why state is the source of truth

<div class="tiles c3">
  <div class="tile purple" v-click>
    <carbon-unlink />
    <h3>Not in state, not managed</h3>
    <p>If Terraform has no record of it, it will not touch it.</p>
  </div>
  <div class="tile purple" v-click>
    <carbon-checkmark-outline />
    <h3>Apply twice, no changes</h3>
    <p>The record matches the code, so there is nothing to do.</p>
  </div>
  <div class="tile purple" v-click>
    <carbon-trash-can />
    <h3>Delete a line, delete a resource</h3>
    <p>State is how Terraform knows what to remove.</p>
  </div>
</div>

<!--
[click] If it is not in state, Terraform does not know it exists and will not manage it.
[click] This is why running apply twice gives "No changes". Tie back to the idea in section 2.
[click] It is how Terraform knows what to delete when you remove a line of code.
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

# Code says X. State says Y. Plan fixes it.

<pre class="term" v-click><span class="dim">  # ibm_is_instance.vsi will be updated in-place</span>
<span class="warn">  ~ resource "ibm_is_instance" "vsi" {</span>
<span class="dim">        id      = "0717_8e51…"</span>
<span class="warn">      ~ profile = "bx2-2x8" -&gt; "bx2-4x16"</span>
<span class="dim">    }</span>

Plan: 0 to add, <span class="warn">1 to change</span>, 0 to destroy.</pre>

<p class="takeaway" v-click>This is the same change you will watch in the demo.</p>

<!--
Use the exact example from the demo: bump the VSI profile.

Code says bx2-4x16. State says bx2-2x8. Plan reads the ID from state, finds that server, and proposes changing one attribute. The other resources are left alone.
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

# The honest part: where state goes wrong

<div class="tiles c4">
  <div class="tile red" v-click>
    <carbon-laptop />
    <h3>Local state</h3>
    <p>It lives on one laptop. Lose the laptop and Terraform forgets everything it built.</p>
  </div>
  <div class="tile red" v-click>
    <carbon-user-multiple />
    <h3>Sharing</h3>
    <p>Two people applying with separate states can collide or duplicate resources.</p>
  </div>
  <div class="tile red" v-click>
    <carbon-compare />
    <h3>Drift</h3>
    <p>Someone edits in the portal. The next plan reveals it.</p>
  </div>
  <div class="tile red" v-click>
    <carbon-locked />
    <h3>Secrets</h3>
    <p>State can hold sensitive values. Protect it like a credential.</p>
  </div>
</div>

<!--
[click] Local state: one laptop. If it dies, the state is gone.
[click] Sharing: two people, two states, a collision.
[click] Drift: someone changes something in the portal. State and reality disagree. Terraform plan is also a drift detector.
[click] Secrets: state can contain sensitive values.
-->

---

<p class="kicker"><b>4</b> · State as source of truth</p>

<p class="hero wide">Who stores state safely, locks it, and controls who sees it?</p>

<p class="lede" v-click>That is the job of <strong>IBM Cloud Schematics</strong>. It is the next session.</p>

<Pipeline :active="1" />

<!--
Land this clearly. Everything that went wrong on the last slide is what Schematics fixes: it stores the state, locks it so two people cannot apply at once, and controls who can see it.

Next is a short checkpoint on state, before section 5.
-->

---

<p class="kicker">Checkpoint</p>

# Does state make sense?

<div class="tiles c3">
  <div class="tile" v-click>
    <h3>Delete a line of code</h3>
    <p>What does Terraform do on the next apply?</p>
  </div>
  <div class="tile" v-click>
    <h3>Apply twice</h3>
    <p>Why does the second run do nothing?</p>
  </div>
  <div class="tile" v-click>
    <h3>The laptop dies</h3>
    <p>What does Terraform forget?</p>
  </div>
</div>

<p class="takeaway" v-click>If any of these feel fuzzy, ask now. Everything after this builds on state.</p>

<!--
Stop here for a minute or two. Ask the room, or answer them yourself if it is quiet.

[click] Delete a line of code: Terraform sees a resource in state that is no longer in the code, so the plan proposes to destroy it.
[click] Apply twice: the code, the state and the cloud already agree, so there is nothing to change.
[click] The laptop dies: if the state was only on that laptop, Terraform no longer knows what it built, and would try to create everything again. That is the problem Schematics solves.
[click] Invite questions.

Transition to section 5: state and Git together give you the third idea. You can prove what changed, who changed it and when.
-->

---

<p class="kicker"><b>5</b> · Auditability</p>

# What changed, who changed it, and when?

<div class="qa">
  <div class="qa-row qa-head"><span></span><span>In the portal</span><span>With Terraform and Git</span></div>
  <div class="qa-row" v-click><b>What changed?</b><span>A screenshot, maybe</span><span>The diff in the commit</span></div>
  <div class="qa-row" v-click><b>Who changed it?</b><span>Whoever had console access</span><span>The author, and who approved it</span></div>
  <div class="qa-row" v-click><b>When?</b><span>Hard to reconstruct</span><span>The commit timestamp</span></div>
  <div class="qa-row" v-click><b>Can we undo it?</b><span>Click it all back, from memory</span><span>Revert the commit and apply</span></div>
</div>

<!--
Open with the questions every customer, auditor and security team eventually asks.

[click] What changed? In the portal, a screenshot if someone took one. With Terraform, the diff in the commit.
[click] Who changed it? The author of the commit and the person who approved the pull request.
[click] When? The commit timestamp.
[click] Can we undo it? Revert the commit and apply. Be careful with this one: it undoes the code, so check the plan first.

Three ways Terraform gets you there: code in Git, the plan as a change record, and validation before anything is built.
-->

---

<p class="kicker"><b>5</b> · Auditability</p>

# The code lives in Git

<div class="cols wide-left" style="align-items:start">
<pre class="term md" v-click><span class="dim">$ git log --oneline</span>
a3f9c21 Bump VSI size for POC load test
7be0d44 Add a second zone for test
1c58aa0 Initial VPC, subnet, VSI
<span class="dim">$ git diff HEAD~1 -- terraform.tfvars</span>
<span class="bad">-vsi_profile = "bx2-2x8"</span>
<span class="ok">+vsi_profile = "bx2-4x16"</span></pre>
  <div class="tiles tight" style="margin-top:0">
    <div class="tile" v-click><h3>History</h3><p>Who changed what, and when.</p></div>
    <div class="tile" v-click><h3>Pull requests</h3><p>Review and approve before it merges.</p></div>
    <div class="tile" v-click><h3>Rollback</h3><p>Revert the commit, then apply.</p></div>
  </div>
</div>

<!--
Nothing exotic here. Infrastructure is now just files, so everything you already know about source control applies.

[click] A real history, with messages that say why. The diff is one line: the server profile.
[click] History: every change, with author and time.
[click] Pull requests: a second pair of eyes before it merges. Approvals are recorded.
[click] Rollback: revert the commit, then plan and apply.

If someone asks about the portal: console changes do not show up here. That is drift, and the next plan reveals it.
-->

---

<p class="kicker"><b>5</b> · Auditability</p>

# The plan is the change record

<div class="flow">
  <div class="stage" v-click>
    <div class="cmd">propose</div>
    <div class="what">Open a pull request with the code change.</div>
    <div class="rw"><b>Reviewers see:</b> the diff</div>
  </div>
  <div class="stage" v-click>
    <div class="cmd">review</div>
    <div class="what">Attach the plan output.</div>
    <div class="rw"><b>Reviewers see:</b> what will be added, changed and destroyed</div>
  </div>
  <div class="stage" v-click>
    <div class="cmd">apply</div>
    <div class="what">Merge, then apply the plan that was approved.</div>
    <div class="rw"><b>Result:</b> reality matches what was approved</div>
  </div>
</div>

<p class="takeaway" v-click>Approve what will actually happen, not a description of it.</p>

<!--
The plan you saw in section 4 is also a review document: it says exactly what will happen before anything does.

[click] propose: the code change goes into a pull request.
[click] review: the plan output is attached. A reviewer can see "1 to change, 0 to destroy" before approving. That is much easier to review than a screenshot of a console.
[click] apply: merge, then apply. You can save a plan to a file with plan -out and apply that exact file, so what you applied is what was reviewed.
[click] Approve what will actually happen.
-->

---

<p class="kicker"><b>5</b> · Auditability</p>

# Catch mistakes before anything is built

<div class="cols" style="grid-template-columns:minmax(0,1.55fr) minmax(0,1fr);gap:24px;margin-top:20px;align-items:start">
  <div class="tiny">

```hcl
variable "vsi_profile" {
  type = string
  validation {
    condition     = startswith(var.vsi_profile, "bx2-")
    error_message = "Use a bx2 profile."
  }
}
```

  </div>
  <pre class="term sm" v-click><span class="bad">Error:</span> Invalid value for variable
<span></span>
  var.vsi_profile is "cx2-2x4"
  Use a bx2 profile.</pre>
</div>

<div class="tiles c3 tight">
  <div class="tile" v-click><h3 class="mono">terraform fmt</h3><p>One consistent format.</p></div>
  <div class="tile" v-click><h3 class="mono">terraform validate</h3><p>Catches syntax and reference mistakes.</p></div>
  <div class="tile" v-click><h3>Variable validation</h3><p>Your own rules for what inputs are allowed.</p></div>
</div>

<!--
Keep this short. The idea: the cheapest place to catch a mistake is before anything exists.

Variable validation is a rule you write next to the variable. If someone passes a profile family you do not allow, Terraform stops with your message, before it plans anything.

[click] The error: it stops at once, with your message.
[click] fmt: formatting, so diffs stay small and readable.
[click] validate: checks the configuration for syntax and reference mistakes without creating anything.
[click] Variable validation: your own rules for what inputs are allowed.

Deeper policy checks come later, with Schematics. Do not go further here.
-->

---

<p class="kicker"><b>6</b> · The road ahead</p>

# Each step answers the pain of the one before

<div class="tiles c4">
  <div class="tile road now" v-click>
    <div class="when">Today</div>
    <h3>Terraform</h3>
    <p>Infrastructure as code, with state and history.</p>
    <div class="pain"><b>Answers</b><span>Click-ops: slow, unrepeatable, unrecorded.</span></div>
  </div>
  <div class="tile road" v-click>
    <div class="when">Next session</div>
    <h3>Schematics</h3>
    <p>Terraform as a service: central state, locking, access control, logs.</p>
    <div class="pain"><b>Answers</b><span>State and runs on one laptop.</span></div>
  </div>
  <div class="tile road" v-click>
    <div class="when">After that</div>
    <h3>Deployable architectures</h3>
    <p>Predefined solutions, such as a VPC landing zone.</p>
    <div class="pain"><b>Answers</b><span>Every team writing and wiring its own code.</span></div>
  </div>
  <div class="tile road" v-click>
    <div class="when">After that</div>
    <h3>Projects</h3>
    <p>Manage deployments as code: configure, validate, approve and deploy across accounts.</p>
    <div class="pain"><b>Answers</b><span>Managing many deployments across environments.</span></div>
  </div>
</div>

<!--
One slide to hold the whole series. Each step is the answer to the pain left by the previous one.

[click] Terraform, today: it answered click-ops.
[click] Schematics, next session: it runs Terraform as a managed service. State is stored centrally, with locking, IAM access control and logs. That answers the one-laptop problem from section 4.
[click] Deployable architectures: predefined solutions such as a VPC landing zone, so teams stop writing and wiring their own from scratch.
[click] Projects: a named collection of configurations. You pick a deployable architecture, add it to a project and set its inputs; the same architecture can have one configuration each for dev, test and production, even across accounts. Changes are validated (commit checks, vulnerability scans, cost estimates), approved by a project admin or editor, then deployed. Projects use Schematics workspaces underneath to hold the state and run Terraform, so people should not edit those workspaces directly. That answers the problem of managing many deployments. The service itself is free; the resources it deploys are billed as usual.

Tease the next session: Schematics.
-->

---

<p class="kicker"><b>6</b> · Recap</p>

# Three ideas to take away

<div class="tiles c3">
  <div class="tile" v-click>
    <carbon-copy />
    <h3>Repeatability</h3>
    <p>Same code, same environment.</p>
  </div>
  <div class="tile purple" v-click>
    <carbon-data-base />
    <h3>State</h3>
    <p>The record Terraform trusts.</p>
  </div>
  <div class="tile green" v-click>
    <carbon-version />
    <h3>Auditability</h3>
    <p>Every change reviewed and recorded.</p>
  </div>
</div>

<!--
[click] Repeatability: the same code gives the same environment.
[click] State: the record Terraform trusts, and the reason plan knows what to change.
[click] Auditability: every change is in Git, and every plan can be reviewed.

Next: questions, then the demo.
-->

---

<p class="kicker">Before the demo</p>

<p class="hero wide">Questions before we build one?</p>

<p class="lede">Repeatability, state or auditability: which one is still fuzzy?</p>

<!--
Leave this up while you take questions. If it is quiet, pick one of these to ask the room:
- Where would a repeatable environment save you the most time with a customer?
- Who on your accounts has been burned by a hand-built environment?

When you are ready, move to the demo.
-->

---

<p class="kicker">Live demo · 10-15 min</p>

# VPC and server, then change it

<div class="steps">
  <span class="step"><i>2-3 min</i> Show the code</span>
  <span class="step"><i>2-3 min</i> init and plan</span>
  <span class="step"><i>2-3 min</i> apply</span>
  <span class="step"><i>2-3 min</i> Change one thing</span>
  <span class="step"><i>2-3 min</i> Wrap</span>
</div>

<div class="tiles c4 tight">
  <div class="tile" v-click><h3>No changes</h3><p>Apply a second time.</p></div>
  <div class="tile" v-click><h3>Resource IDs</h3><p>terraform state list</p></div>
  <div class="tile" v-click><h3>In-place update</h3><p>Bump the server profile.</p></div>
  <div class="tile" v-click><h3>The git diff</h3><p>Your audit trail.</p></div>
</div>

<!--
Run it live.

1. Show the code (2-3 min): provider, VPC, subnet, server, and the variables. Point at the variables.
2. init and plan (2-3 min): read the plan out loud. "N to add."
3. apply (2-3 min): resources appear in the console. Run terraform state list and point at the IDs. Do not cat the whole state file.
4. Change one thing (2-3 min): bump the server profile. The plan reads the ID from state and shows one change. Say whether it is an in-place update or a replacement.
5. Wrap (2-3 min): git diff is the audit trail. Optional destroy.

Watch for these callbacks:
- Section 2: a second apply says "No changes".
- Section 3: change name_prefix and the plan proposes a whole new set of resources.
- Section 4: the plan reads from state.
- Section 5: the git diff.

Tips: pre-run init, and keep a pre-built copy as a fallback. Use a small profile and a single zone so apply finishes fast. Keep secrets in fnox or environment variables, never on screen.
-->
