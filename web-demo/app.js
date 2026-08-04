const tabs = [...document.querySelectorAll("[data-tab]")];
const screens = [...document.querySelectorAll("[data-screen]")];
const dialog = document.querySelector("#scan-dialog");
const scanState = document.querySelector("#scan-state");
const reviewState = document.querySelector("#review-state");
const dialogTitle = document.querySelector("#dialog-title");
const toast = document.querySelector("#toast");

function switchTab(name) {
  tabs.forEach((tab) => tab.classList.toggle("active", tab.dataset.tab === name));
  screens.forEach((screen) => screen.classList.toggle("active", screen.dataset.screen === name));
}

tabs.forEach((tab) => tab.addEventListener("click", () => switchTab(tab.dataset.tab)));

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove("show"), 2400);
}

document.querySelectorAll(".scan-trigger").forEach((button) => {
  button.addEventListener("click", () => {
    scanState.hidden = false;
    reviewState.hidden = true;
    dialogTitle.textContent = "Scan receipt";
    dialog.showModal();
    setTimeout(() => {
      if (!dialog.open) return;
      scanState.hidden = true;
      reviewState.hidden = false;
      dialogTitle.textContent = "Review receipt";
    }, 1250);
  });
});

document.querySelector("#close-scan").addEventListener("click", () => dialog.close());
dialog.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); });

reviewState.addEventListener("submit", (event) => {
  event.preventDefault();
  const form = new FormData(reviewState);
  const merchant = form.get("merchant");
  const total = Number(form.get("total")).toLocaleString("en-US");
  const row = document.createElement("article");
  row.className = "receipt-row";
  row.dataset.search = `${merchant} meals tokyo work trip`.toLowerCase();
  row.innerHTML = `<span class="category-icon">♨</span><span><strong>${merchant}</strong><small>Meals · Tokyo work trip</small></span><b>¥ ${total}<small>Just now</small></b>`;
  document.querySelector("#receipt-list").prepend(row);
  dialog.close();
  switchTab("receipts");
  showToast("Receipt saved to Tokyo work trip");
});

document.querySelector("#receipt-search").addEventListener("input", (event) => {
  const query = event.target.value.trim().toLowerCase();
  document.querySelectorAll(".receipt-row").forEach((row) => {
    row.hidden = query && !row.dataset.search.includes(query);
  });
});

document.querySelector("#new-matter").addEventListener("click", () => {
  const list = document.querySelector("#matter-list");
  if (document.querySelector("#sample-matter")) return showToast("Sample matter already added");
  const matter = document.createElement("button");
  matter.className = "matter-row";
  matter.id = "sample-matter";
  matter.innerHTML = `<span class="matter-icon blue">＋</span><span class="matter-copy"><strong>New sample matter</strong><small>0 receipts · Today</small></span><span class="matter-total"><strong>S$ 0.00</strong><small>View ›</small></span>`;
  list.append(matter);
  showToast("New sample matter created");
});

document.querySelector("#export-button").addEventListener("click", () => {
  const format = document.querySelector("#export-format").value;
  if (format === "CSV table") {
    const csv = "Date,Merchant,Matter,Category,Currency,Total\n2026-07-16,Kissa Ginza,Tokyo work trip,Meals,JPY,1700\n2026-07-12,Hotel Gracery,Tokyo work trip,Accommodation,JPY,18630";
    const link = document.createElement("a");
    link.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
    link.download = "receipt-archive-sample.csv";
    link.click();
    URL.revokeObjectURL(link.href);
    showToast("Sample CSV downloaded");
  } else {
    showToast(`${format} is prepared in the native app`);
  }
});

