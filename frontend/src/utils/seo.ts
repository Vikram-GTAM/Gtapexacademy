// Page titles, descriptions, sharing tags and structured data. Set from one place, with no extra library.
import { useEffect } from "react";
import type { CourseCard } from "../types";
import { ADDRESS, EMAIL, INSTAGRAM, PHONE_LINK } from "./contactInfo";

export const SITE_NAME = "GTapex Academy";
const SITE_URL = ((import.meta.env.VITE_SITE_URL as string | undefined) ?? "").replace(/\/$/, "");
const siteUrl = () => SITE_URL || window.location.origin;

export interface PageMeta {
  title: string;
  description?: string;
  /** Pages that shouldn't appear in search results: logins, dashboards, not-found. */
  noindex?: boolean;
  jsonLd?: object;
  image?: string | null;
}

function setTag(selector: string, create: () => HTMLElement, attr: string, value: string | null) {
  let el = document.head.querySelector<HTMLElement>(selector);
  if (value === null) { el?.remove(); return; }
  if (!el) { el = create(); document.head.appendChild(el); }
  el.setAttribute(attr, value);
}
const named = (name: string, value: string | null) => setTag(`meta[name="${name}"]`, () => Object.assign(document.createElement("meta"), { name }), "content", value);
const property = (prop: string, value: string | null) => setTag(`meta[property="${prop}"]`, () => { const m = document.createElement("meta"); m.setAttribute("property", prop); return m; }, "content", value);

const absolute = (path: string) => (/^https?:\/\//.test(path) ? path : siteUrl() + path);

export function setPageMeta({ title, description, noindex = false, jsonLd, image }: PageMeta) {
  const url = siteUrl() + window.location.pathname;
  document.title = title;
  if (description) { named("description", description); property("og:description", description); }
  named("robots", noindex ? "noindex" : null);
  setTag('link[rel="canonical"]', () => Object.assign(document.createElement("link"), { rel: "canonical" }), "href", noindex ? null : url);
  property("og:title", title);
  property("og:url", url);
  property("og:image", absolute(image || "/og-image.png"));

  document.getElementById("page-jsonld")?.remove();
  if (jsonLd) {
    const script = document.createElement("script");
    script.id = "page-jsonld";
    script.type = "application/ld+json";
    script.textContent = JSON.stringify(jsonLd);
    document.head.appendChild(script);
  }
}

export function usePageMeta(meta: PageMeta | null) {
  const key = meta ? JSON.stringify(meta) : null;
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { if (meta) setPageMeta(meta); }, [key]);
}

const provider = () => ({ "@type": "EducationalOrganization", name: SITE_NAME, url: siteUrl() });

export const organizationJsonLd = () => ({
  "@context": "https://schema.org",
  ...provider(),
  logo: absolute("/og-image.png"),
  email: EMAIL,
  telephone: PHONE_LINK,
  address: { "@type": "PostalAddress", streetAddress: ADDRESS, addressLocality: "Hyderabad", addressRegion: "Telangana", postalCode: "500081", addressCountry: "IN" },
  sameAs: [INSTAGRAM],
});

export function courseMeta(c: CourseCard): PageMeta {
  const offer = (price: number, category: string) => ({ "@type": "Offer", price, priceCurrency: "INR", category, url: siteUrl() + window.location.pathname, availability: "https://schema.org/InStock" });
  const offers = [
    ...(c.offline_only ? [] : [offer(c.price, "Online")]),
    ...(c.offline_price != null ? [offer(c.offline_price, "Offline")] : []),
  ];
  return {
    title: `${c.title} | ${SITE_NAME}`,
    description: c.short_description,
    image: c.thumbnail_url,
    jsonLd: {
      "@context": "https://schema.org",
      "@type": "Course",
      name: c.title,
      description: c.short_description,
      provider: provider(),
      ...(c.thumbnail_url ? { image: absolute(c.thumbnail_url) } : {}),
      offers,
      hasCourseInstance: [
        ...(c.offline_only ? [] : [{ "@type": "CourseInstance", courseMode: "online" }]),
        ...(c.offline_price != null ? [{ "@type": "CourseInstance", courseMode: "onsite", location: { "@type": "Place", name: SITE_NAME, address: ADDRESS } }] : []),
      ],
    },
  };
}
