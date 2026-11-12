import { useEffect, useRef } from "react";
import { useLocation, useNavigationType } from "react-router-dom";

/** Opens every page from the top, including a link to the page you're already on. */
export function ScrollToTop() {
  const { key, pathname, search, hash } = useLocation();
  const navigationType = useNavigationType();
  const previous = useRef({ pathname, search });

  useEffect(() => {
    const before = previous.current;
    previous.current = { pathname, search };
    // The browser restores the position on back and forward; links to a section go to that section.
    if (navigationType === "POP" || hash) return;
    // Changing a filter or search on the same page keeps your place.
    if (pathname === before.pathname && search !== before.search) return;
    window.scrollTo({ top: 0, left: 0, behavior: "instant" });
  }, [key, pathname, search, hash, navigationType]);

  return null;
}
