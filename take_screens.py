from playwright.sync_api import sync_playwright

shot_no = 0  # running counter so files sort in click order

def snap(page, label):
    """Save a numbered screenshot, e.g. 03-create-subnet.png."""
    global shot_no
    shot_no += 1
    page.wait_for_load_state("networkidle")  # let the console finish rendering
    page.screenshot(path=f"shots/{shot_no:02d}-{label}.png")

with sync_playwright() as p:
    browser = p.chromium.launch(
    	channel="chrome",
    	headless=False,
    	args=["--disable-http2", "--disable-blink-features=AutomationControlled"],
	)

    # Reuse the saved login; fixed viewport keeps every screenshot the same size
    ctx = browser.new_context(storage_state="auth.json",
                              viewport={"width": 1440, "height": 900})
    page = ctx.new_page()

    page.goto("https://cloud.ibm.com/vpc-ext/network/vpcs")
    snap(page, "vpc-list")

    page.get_by_role("button", name="Create").click()  # pasted from codegen
    snap(page, "create-vpc-form")
    # ...repeat: click, then snap()
