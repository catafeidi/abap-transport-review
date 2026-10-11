# ATC checks at the release of tasks and requests (optional)

How to make the standard run ATC when a task or a request is released, and refuse the release when there are findings of priority 1 or 2. No custom code is involved. The review workflow works without it; with it, code with blocking findings reaches neither the review branch nor the base branch.

These are system-wide settings. They apply to every package and every developer from the moment they are saved. The screens differ a little between releases, so a label may read slightly differently on your system. Do this on a development system first.

## Step 1. Create the check variant

Transaction **SCI**.

1. Block "Check Variant": name for example `Z_RELEASE_CHECKS`. Click the icon next to the name until it shows **global**, not user-specific. Click **Create**.
2. Tick the checks you want. A common start is SAP's variant `DEFAULT`, plus Syntax Check/Generation, **Syntax Check**, and Dynamic Tests, **ABAP Unit** with risk level harmless and duration short. Add the **abaplint** check if you use it ([ABAPLINT-IN-SAP.md](ABAPLINT-IN-SAP.md)).
3. Save.

Everything in this variant that reports priority 1 or 2 will later block a release. With ABAP Unit in the variant, a failing unit test stops the release.

## Step 2. Configure ATC, first in "inform" mode

Transaction **ATC**, then ATC Administration, Setup, **Basic Settings**. This needs ATC administrator rights.

1. Master system: the system itself. RFC destination of the master system: empty.
2. Global check variant: the variant of step 1.
3. Transport Tool Integration, ATC: **Inform on errors (priority 1 and 2)**.
4. Transport Tool Integration, Code Inspector: **Disable "Code Inspector" as test driver**. Otherwise every release is checked twice.
5. Save.

## Step 3. Extend the check to tasks

Transaction **SE03**, Administration, **Global Customizing (Transport Organizer)**.

1. Block "Objects are checked when request released": keep **Globally activated**.
2. Block with the checkboxes for which releases are checked: tick **requests** and **tasks**. Leave transports of copies unticked.
3. Save.

From now on every release of a task or request shows the ATC findings and still lets the developer continue.

## Step 4. Measure before blocking

1. SE80, a package under Git, context menu, Check, **ABAP Test Cockpit (ATC) with**, the variant of step 1.
2. Count the findings of priority 1 and 2. These are what would block.
3. Fix them, or remove a check from the variant if its findings are not worth a block.

ATC checks whole objects, not the changed lines. A one-line change in an old class fails on every old finding in that class. So the count must be near zero before step 5.

## Step 5. Switch to "block"

Transaction **ATC**, Basic Settings: Transport Tool Integration, ATC: **Block on any error (priority 1 and 2)**. Save. From now on a task or request with a finding of priority 1 or 2 is not released.

## How it works together with the review workflow

The BAdI of this repository starts the push job of a task before the release. The job waits until the task really is released. If ATC (or any later check of the release) refuses the release, the task stays unreleased; the job waits up to 10 minutes, sees that it did not happen, and ends without pushing. So the code of a refused release is not pushed.

## Switch it off again

- ATC, Basic Settings: Transport Tool Integration, ATC: **No ATC check**.
- SE03, Global Customizing: untick **tasks**.
