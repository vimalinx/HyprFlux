async function copyText(text, button) {
  const original = button.textContent;
  try {
    await navigator.clipboard.writeText(text);
    button.textContent = "Copied";
    button.classList.add("copied");
  } catch (_) {
    const range = document.createRange();
    const cmd = button.parentElement.querySelector(".cmd");
    range.selectNodeContents(cmd);
    const sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    button.textContent = "Select & copy";
  }
  setTimeout(() => {
    button.textContent = original;
    button.classList.remove("copied");
  }, 1600);
}

document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", () => {
    const cmd = button.parentElement.querySelector(".cmd");
    const text = cmd.textContent.trim();
    copyText(text, button);
  });
});
