const cmd = document.getElementById("cmd");
const btn = document.getElementById("copy");
const text = cmd.textContent.trim();

btn.addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(text);
    btn.textContent = "Copied";
    btn.classList.add("copied");
    setTimeout(() => {
      btn.textContent = "Copy";
      btn.classList.remove("copied");
    }, 1600);
  } catch (_) {
    const range = document.createRange();
    range.selectNodeContents(cmd);
    const sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    btn.textContent = "Select & copy";
  }
});
