const themeScript = `(() => {
  const key = "csig-theme-preference";
  const stored = localStorage.getItem(key);
  const preference = stored === "day" || stored === "night" || stored === "auto" ? stored : "auto";
  const hour = new Date().getHours();
  document.documentElement.dataset.theme = preference === "auto" ? (hour >= 6 && hour < 18 ? "day" : "night") : preference;
})();`;

export function ThemeScript() {
  return <script dangerouslySetInnerHTML={{ __html: themeScript }} />;
}
