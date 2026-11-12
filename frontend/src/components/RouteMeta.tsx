import { useEffect } from "react";
import { useLocation } from "react-router-dom";
import { organizationJsonLd, setPageMeta, SITE_NAME, type PageMeta } from "../utils/seo";

const PUBLIC_PAGES: Record<string, PageMeta> = {
  "/courses": { title: `Marketing Courses, Online & Offline | ${SITE_NAME}`, description: "Browse GTapex Academy's marketing courses: SEO, social media, analytics, video editing, graphic design and more, online or in our Hyderabad classroom." },
  "/about": { title: `About Us | ${SITE_NAME}`, description: "Learn how GTapex Academy teaches practical marketing through online and classroom courses, live case studies and certifications." },
  "/placements": { title: `Placement Assistance | ${SITE_NAME}`, description: "Resume and portfolio reviews, mock interviews, LinkedIn help and introductions to hiring partners for GTapex Academy students." },
  "/book-demo": { title: `Book a Free Demo | ${SITE_NAME}`, description: "Book a free, no-commitment demo with GTapex Academy to see the course content and ask about the syllabus and fees." },
  "/contact": { title: `Contact Us | ${SITE_NAME}`, description: "Call, WhatsApp or email GTapex Academy, or visit our office in Madhapur, Hyderabad." },
  "/refund-policy": { title: `Refund Terms | ${SITE_NAME}`, description: "When you can get your money back from GTapex Academy, and how to ask for it." },
};

const HOME: PageMeta = {
  title: `${SITE_NAME} | Master Marketing with Online & Offline Classes`,
  description: "Placement assistance, online and offline classes, fundamentals of marketing, live case studies, personal entrepreneurship and certifications at GTapex Academy, Hyderabad.",
};

function metaFor(path: string): PageMeta {
  const clean = path.replace(/\/$/, "") || "/";
  if (clean === "/") return { ...HOME, jsonLd: organizationJsonLd() };
  if (PUBLIC_PAGES[clean]) return PUBLIC_PAGES[clean];
  // The course page replaces this as soon as the course has loaded.
  if (clean.startsWith("/courses/")) return { title: `Course | ${SITE_NAME}`, description: HOME.description };
  // Sign-in pages, dashboards, admin and anything unknown stay out of search results.
  return { title: SITE_NAME, noindex: true };
}

/** Keeps the title and search tags in step with the page. */
export function RouteMeta() {
  const { pathname } = useLocation();
  useEffect(() => { setPageMeta(metaFor(pathname)); }, [pathname]);
  return null;
}
