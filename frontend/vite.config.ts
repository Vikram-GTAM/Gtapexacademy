import react from "@vitejs/plugin-react";
import { appendFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { defineConfig, loadEnv, type Plugin } from "vite";

const STATIC_PAGES = ["/", "/courses", "/about", "/placements", "/book-demo", "/contact", "/refund-policy"];

/** With VITE_SITE_URL set, the build adds a sitemap of every page and published course, and full sharing links. */
function seoFiles(env: Record<string, string>): Plugin {
  const site = (env.VITE_SITE_URL ?? "").replace(/\/$/, "");
  let outDir = "dist";
  return {
    name: "gtapex-seo-files",
    apply: "build",
    configResolved(config) { outDir = resolve(config.root, config.build.outDir); },
    transformIndexHtml(html) {
      return site ? html.replace("</head>", `  <meta property="og:image" content="${site}/og-image.png" />\n    <meta property="og:url" content="${site}/" />\n  </head>`) : html;
    },
    async closeBundle() {
      if (!site) { console.warn("VITE_SITE_URL is not set: no sitemap built. Set it to the website's address before going live."); return; }
      let courses: { id: string }[] = [];
      try {
        const res = await fetch(`${env.VITE_SUPABASE_URL}/rest/v1/rpc/list_courses`, {
          method: "POST",
          headers: { apikey: env.VITE_SUPABASE_ANON_KEY, "Content-Type": "application/json" },
          body: JSON.stringify({ p_page_size: 60 }),
        });
        if (!res.ok) throw new Error(`status ${res.status}`);
        courses = (await res.json()).items;
      } catch (error) {
        console.warn(`Sitemap: couldn't load courses (${error}). Only the main pages are listed.`);
      }
      const paths = [...STATIC_PAGES, ...courses.map((c) => `/courses/${c.id}`)];
      const urls = paths.map((p) => `  <url><loc>${site}${p === "/" ? "/" : p}</loc></url>`).join("\n");
      writeFileSync(resolve(outDir, "sitemap.xml"), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`);
      appendFileSync(resolve(outDir, "robots.txt"), `\nSitemap: ${site}/sitemap.xml\n`);
    },
  };
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "VITE_");
  return {
    plugins: [react(), seoFiles(env)],
    server: { port: 5173 },
    build: {
      rollupOptions: {
        output: {
          // Rarely changing libraries get their own files, so returning visitors keep them cached after each update.
          manualChunks(id) {
            if (/node_modules\/(react|react-dom|react-router|react-router-dom|@remix-run|scheduler)\//.test(id)) return "react";
            if (/node_modules\/@supabase\//.test(id)) return "supabase";
          },
        },
      },
    },
  };
});
