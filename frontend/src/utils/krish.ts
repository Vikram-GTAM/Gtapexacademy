// Krish, the GTapex assistant. She follows the same workflow as the assistant on gtapexmarketing.com: a greeting bubble,
// a typing pause before each reply, one-tap options, and a step-by-step enquiry that reaches the team. Answers come from
// this file and the live course list. Anything not covered here is offered to the team rather than guessed.
import type { CourseCard } from "../types";
import { ADDRESS, EMAIL, HOURS, INSTAGRAM, MAP_LINK, PHONE, PHONE_LINK, WHATSAPP_LINK } from "./contactInfo";
import { formatPrice } from "./format";

/** A one-tap option: `href` opens a page or link, `quick` sends that text as the visitor's message. */
export interface KrishAction { label: string; href?: string; quick?: string }
export interface KrishReply {
  text: string;
  actions?: KrishAction[];
  /** The course this reply was about, so "how much is it?" can follow on from it. */
  courseId?: string;
}

const PLACEMENT = "100-placement-programme";
const COMBO = "video-editing-graphic-designer-combo";
const ENTREPRENEURSHIP = "entrepreneurship-programme";
const NOT_IN_PLACEMENT = [PLACEMENT, COMBO, ENTREPRENEURSHIP];

const TALK = "Talk to the team";
export const RETRY = "__retry";

export const STARTER_ACTIONS: KrishAction[] = [
  { label: "Our courses", quick: "What courses do you offer?" },
  { label: "100% Placement Programme", quick: "Tell me about the 100% Placement Programme" },
  { label: "Book a free demo", quick: "Book a free demo" },
  { label: TALK, quick: TALK },
];
export const GREETING_FIRST = "Hi, I'm Krish, the GTapex assistant. 👋";
export const GREETING_SECOND = "I can tell you about our courses, book you a free demo, or connect you with our team. What would you like to do?";
export const INTEREST_OPTIONS = ["Digital Marketing", "SEO", "Social Media", "Video & Design", "100% Placement Programme", "Entrepreneurship", "Not sure yet"];

const LINKS = {
  courses: { label: "All courses", href: "/courses" },
  demo: { label: "Book a free demo", href: "/book-demo" },
  contact: { label: "Contact us", href: "/contact" },
  refund: { label: "Refund terms", href: "/refund-policy" },
  placements: { label: "Placements", href: "/placements" },
  call: { label: "Call us", href: `tel:${PHONE_LINK}` },
  email: { label: "Email us", href: `mailto:${EMAIL}` },
  whatsapp: { label: "Chat on WhatsApp", href: WHATSAPP_LINK },
  instagram: { label: "Follow us on Instagram", href: INSTAGRAM },
  map: { label: "Open map", href: MAP_LINK },
  specialist: { label: "Talk to a specialist", quick: TALK },
};

/** How long the typing dots show before a reply. */
export const typingDelay = (text: string, reducedMotion = false) => (reducedMotion ? 150 : 550 + Math.min(700, 6 * text.length));

// ---------------------------------------------------------------- The enquiry

export type Stage = "chat" | "name" | "contact" | "interest" | "message" | "sending" | "done";
export interface Enquiry { name: string; contact: string; interest: string; message: string }
export const EMPTY_ENQUIRY: Enquiry = { name: "", contact: "", interest: "", message: "" };

const IS_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const IS_PHONE = /^\+?[\d\s-]{7,16}$/;
export const firstName = (name: string) => name.split(" ")[0];

export const PLACEHOLDERS: Record<Stage, string> = {
  chat: "Type your question…",
  name: "Your name",
  contact: "Phone number or email",
  interest: "Pick an option or type",
  message: "Tell us a little more",
  sending: "Type your question…",
  done: "Type your question…",
};

const CANCEL: KrishAction = { label: "Cancel", quick: "Cancel" };
const IS_CANCEL = /^(cancel|stop|exit|quit|never ?mind|go back|no thanks|not now)[.!]*$/i;

/** What Krish asks at each step. */
function stepPrompt(stage: Stage): KrishReply {
  switch (stage) {
    case "name": return { text: "What's your name?", actions: [CANCEL] };
    case "contact": return { text: "What's the best phone number or email to reach you?", actions: [CANCEL] };
    case "interest": return { text: "Which course are you most interested in?", actions: [...INTEREST_OPTIONS.map((label) => ({ label, quick: label })), CANCEL] };
    default: return { text: "Anything else our team should know about you or your goals?", actions: [{ label: "Skip", quick: "Skip" }, CANCEL] };
  }
}

const QUESTION_START = /^(how|what|whats|when|where|why|which|who|can|could|do|does|did|is|are|should|would|tell|show|give|i want|i need)\b.*\s/i;
const LONG_WILL = /^will(\s+\S+){2,}/i;
const TOPIC = /\b(price|prices|fee|fees|cost|costs|course|courses|refund|refunds|placement|placements|demo|syllabus|certificate|duration|marketing|seo)\b/i;

/** True when the visitor asked something instead of answering. The last step is free text, so a question there is their message. */
function isSideQuestion(stage: Stage, text: string): boolean {
  if (text.includes("?") || QUESTION_START.test(text) || LONG_WILL.test(text)) return true;
  if (stage === "interest") return /\b(price|prices|fee|fees|cost|costs|refund|refunds)\b/i.test(text);
  return TOPIC.test(text);
}

function answerThenAskAgain(stage: Stage, text: string, courses: CourseCard[] | null, lastCourseId?: string): KrishReply {
  const prompt = stepPrompt(stage);
  if (startsEnquiry(text)) return { text: `You're in the right place. I just need a few details for our team.\n\n${prompt.text}`, actions: prompt.actions };
  const side = answer(text, courses, lastCourseId);
  const body = side.text === OFFER_TEXT ? "Our team can answer that when they get in touch." : side.text;
  // One-tap questions would be taken as the answer to this step, so only page links are kept.
  const links = (side.actions ?? []).filter((a) => a.href);
  return { text: `${body}\n\nBack to your enquiry: ${prompt.text}`, actions: [...links, ...(prompt.actions ?? [])], courseId: side.courseId };
}

/** The next step of the enquiry, given what the visitor just typed. `submit` means every step is complete. */
export function enquiryStep(stage: Stage, enquiry: Enquiry, text: string, courses: CourseCard[] | null = null, lastCourseId?: string): { stage: Stage; enquiry: Enquiry; reply?: KrishReply; submit?: boolean } {
  if (IS_CANCEL.test(text)) return { stage: "chat", enquiry: EMPTY_ENQUIRY, reply: { text: "No problem, I've cancelled that. What else can I help with?", actions: STARTER_ACTIONS } };
  const isContact = stage === "contact" && (IS_EMAIL.test(text) || IS_PHONE.test(text));
  if ((stage === "name" || stage === "contact" || stage === "interest") && !isContact && isSideQuestion(stage, text)) {
    return { stage, enquiry, reply: answerThenAskAgain(stage, text, courses, lastCourseId) };
  }
  switch (stage) {
    case "name": {
      const name = text.slice(0, 80);
      if (IS_GREETING.test(parse(text).text)) return { stage, enquiry, reply: { text: "Hello! What's your name?", actions: [CANCEL] } };
      if (name.length < 2 || !/\p{L}/u.test(name)) return { stage, enquiry, reply: { text: "Could you share your name, so our team knows who to ask for?", actions: [CANCEL] } };
      return { stage: "contact", enquiry: { ...enquiry, name }, reply: { text: `Nice to meet you, ${firstName(name)}! ${stepPrompt("contact").text}`, actions: [CANCEL] } };
    }
    case "contact":
      if (!isContact) return { stage, enquiry, reply: { text: "Hmm, that doesn't look like a phone number or email. Could you check it?", actions: [CANCEL] } };
      return { stage: "interest", enquiry: { ...enquiry, contact: text }, reply: { ...stepPrompt("interest"), text: `Thanks! ${stepPrompt("interest").text}` } };
    case "interest":
      return { stage: "message", enquiry: { ...enquiry, interest: text.slice(0, 80) }, reply: { ...stepPrompt("message"), text: `Got it. ${stepPrompt("message").text}` } };
    case "message":
      return { stage: "sending", enquiry: { ...enquiry, message: /^skip$/i.test(text) ? "" : text.slice(0, 1000) }, submit: true };
    default:
      return { stage, enquiry };
  }
}

export const enquirySent = (enquiry: Enquiry): KrishReply => ({
  text: `Thanks, ${firstName(enquiry.name)}! Your details are with our team and someone will reach out within one working day.`,
  actions: [LINKS.whatsapp, LINKS.instagram, LINKS.demo],
});

export const enquiryFailed = (): KrishReply => ({
  text: `Sorry, that didn't go through. Please try sending again, or call us on ${PHONE}.`,
  actions: [{ label: "Try again", quick: RETRY }, CANCEL],
});

const asksForOurDetails = /\b(your|ur|gtapex)\b.*\b(phone|number|whatsapp|email|mail)\b/i;
const wantsTheTeam = /talk|\bhuman\b|\b(a|real) person\b|team|contact me|call me|reach|whatsapp|phone|get in touch|speak|yes,? contact/i;

/** True when the visitor wants a person, which starts the enquiry. */
export const startsEnquiry = (text: string) => !asksForOurDetails.test(text) && wantsTheTeam.test(text);
export const ENQUIRY_START: KrishReply = { text: "Great, I'll connect you with our team. First, what's your name?", actions: [CANCEL] };

// ---------------------------------------------------------------- Reading the question

interface Question { text: string; tokens: string[] }

function parse(raw: string): Question {
  const text = raw.toLowerCase().replace(/[^a-z0-9%₹\s]/g, " ").replace(/\s+/g, " ").trim();
  return { text, tokens: text ? text.split(" ") : [] };
}

function editDistance(a: string, b: string): number {
  let row = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const next = [i];
    for (let j = 1; j <= b.length; j++) next[j] = Math.min(row[j] + 1, next[j - 1] + 1, row[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    row = next;
  }
  return row[b.length];
}

/** Forgives plurals and typos in longer words ("placemet", "certficate"), but short words must match exactly. */
function sameWord(token: string, word: string): boolean {
  if (token === word) return true;
  if (word.length < 4) return false;
  if (token.startsWith(word)) return true;
  const allowed = word.length >= 9 ? 2 : word.length >= 6 ? 1 : 0;
  return allowed > 0 && Math.abs(token.length - word.length) <= allowed && editDistance(token, word) <= allowed;
}

/** True if the question has any of these words. An entry with a space must appear as that exact phrase. */
function has(q: Question, words: string[]): boolean {
  return words.some((w) => (w.includes(" ") ? ` ${q.text} `.includes(` ${w} `) : q.tokens.some((t) => sameWord(t, w))));
}

// ---------------------------------------------------------------- Finding the course

// Words too common to identify a course on their own.
const GENERIC = new Set(["and", "the", "of", "for", "in", "marketing", "course", "courses", "programme", "program", "professional", "driven", "100%", "100", "ai", "search", "media", "content"]);

// Other ways people refer to a course. Courses added later still match on the words in their title.
const ALIASES: Record<string, string[]> = {
  "marketing-analytics-and-ai-driven-marketing": ["analytics", "ga4", "ai", "ai driven", "ai marketing"],
  "website-landing-marketing": ["web", "landing page", "website marketing"],
  "social-media-content-marketing": ["instagram", "social media", "content marketing"],
  "seo-ai-search-optimization": ["ai search", "search engine", "ranking", "search optimization"],
  "digital-marketing-professional": ["digital marketing"],
  "graphic-designer": ["design", "designing", "designer"],
  "video-editing": ["videoediting", "editor"],
  [COMBO]: ["design", "designing", "videoediting", "editor"],
  [ENTREPRENEURSHIP]: ["entrepreneur", "startup"],
};

const titleWords = (c: CourseCard) => parse(c.title).tokens.filter((w) => !GENERIC.has(w));

function findCourse(q: Question, courses: CourseCard[]): CourseCard | undefined {
  let best: { course: CourseCard; score: number; words: number } | undefined;
  for (const course of courses) {
    const words = titleWords(course);
    const aliases = ALIASES[course.slug] ?? [];
    const single = [...words, ...aliases.filter((a) => !a.includes(" "))];
    let score = q.tokens.filter((t) => single.some((w) => sameWord(t, w))).length;
    score += aliases.filter((a) => a.includes(" ") && has(q, [a])).length * 2;
    if (!score) continue;
    // On a tie, the course with the shorter title fits better: "video editing" means Video Editing, not the combo.
    if (!best || score > best.score || (score === best.score && words.length < best.words)) best = { course, score, words: words.length };
  }
  return best?.course;
}

// ---------------------------------------------------------------- Wording

const price = (c: CourseCard) => formatPrice(c.offline_price ?? c.price);

function fees(c: CourseCard): string {
  if (c.offline_only) return `${price(c)}, classroom only`;
  if (c.offline_price == null) return `${formatPrice(c.price)} online`;
  return `${formatPrice(c.price)} online or ${formatPrice(c.offline_price)} offline`;
}

const length = (c: CourseCard) => (c.duration_months ? `${c.duration_months} months` : "");
const feeLine = (c: CourseCard) => `• ${c.title}: ${fees(c)}`;
const viewCourse = (c: CourseCard): KrishAction => ({ label: "View course", href: `/courses/${c.id}` });

function courseSummary(c: CourseCard): KrishReply {
  const parts = [`Yes, ${c.title} is one of our courses: ${fees(c)}.`];
  if (c.duration_months) parts.push(`It runs for ${length(c)}.`);
  if (c.offline_price != null) parts.push(c.offline_only ? "It includes placement assistance." : "The offline option includes placement assistance.");
  return { text: parts.join(" "), actions: [viewCourse(c), LINKS.specialist], courseId: c.id };
}

const contactReply = (): KrishReply => ({
  text: `Our team is available ${HOURS}.\nPhone and WhatsApp: ${PHONE}\nEmail: ${EMAIL}`,
  actions: [LINKS.call, LINKS.whatsapp, LINKS.email],
});

const noCourseData = (): KrishReply => ({
  text: "I can't load the course list right now. Please try again in a moment, or see the courses page.",
  actions: [LINKS.courses, { label: TALK, quick: TALK }],
});

function placementReply(courses: CourseCard[]): KrishReply {
  const programme = courses.find((c) => c.slug === PLACEMENT);
  const included = courses.filter((c) => !NOT_IN_PLACEMENT.includes(c.slug)).map((c) => c.title);
  const lines: string[] = [];
  if (programme) {
    lines.push(`${programme.title}: ${fees(programme)}${programme.duration_months ? `, ${length(programme)}` : ""}.`);
    if (included.length) lines.push(`It includes: ${included.join(", ")}.`);
  }
  lines.push("Placement support covers resume and portfolio reviews, mock interviews, LinkedIn help and introductions to hiring partners. Every offline course includes placement assistance.");
  lines.push("It's guidance and introductions, so it doesn't guarantee a job offer, and not being placed isn't a reason for a refund.");
  return { text: lines.join("\n"), actions: [...(programme ? [viewCourse(programme)] : []), LINKS.placements, LINKS.specialist], courseId: programme?.id };
}

function recommendReply(courses: CourseCard[]): KrishReply {
  const name = (slug: string) => courses.find((c) => c.slug === slug)?.title;
  const options: [string, string | undefined][] = [
    ["Want placement support and a wide range of skills", name(PLACEMENT)],
    ["Want all-round marketing skills", name("digital-marketing-professional")],
    ["Want to build your own business", name(ENTREPRENEURSHIP)],
    ["Enjoy creative work", name(COMBO)],
  ];
  const lines = options.filter(([, title]) => title).map(([goal, title]) => `• ${goal}: ${title}`);
  return { text: `It depends on your goal:\n${lines.join("\n")}`, actions: [LINKS.demo, { label: "Help me choose", quick: TALK }] };
}

const OFFER_TEXT = "Good question. Our team can answer that best. Shall I pass your details to them? They usually reply within one working day.";
const offerTheTeam = (): KrishReply => ({
  text: OFFER_TEXT,
  actions: [{ label: "Yes, contact me", quick: TALK }, { label: "See courses", href: "/courses" }],
});

// ---------------------------------------------------------------- Answering

const IS_GREETING = /^(hi+|hai+|hello+|hey+|helo+|namaste|namaskar|good (morning|afternoon|evening)|yo|hola)( krish| there| team)?$/;
const IS_THANKS = /^(thanks?|thank you|thankyou|thx|ty|ok|okay|ok thanks|okay thanks|great|awesome|cool|nice|got it|bye|goodbye)( krish| you| so much| a lot)*$/;
const FOLLOW_ON = ["it", "this", "that", "its", "same"];

/** The answer to one question in normal chat. `courses` is null if the list couldn't be loaded. */
export function answer(raw: string, courses: CourseCard[] | null, lastCourseId?: string): KrishReply {
  const q = parse(raw);
  const list = courses ?? [];
  const named = findCourse(q, list);
  // "how much is it?" and "fees?" follow on from the course just discussed; "course fees" asks about all of them.
  const followsOn = q.tokens.some((t) => FOLLOW_ON.includes(t)) || (q.tokens.length <= 2 && !has(q, ["course", "courses", "all"]));
  const last = followsOn ? list.find((c) => c.id === lastCourseId) : undefined;
  const course = named ?? last;

  if (IS_GREETING.test(q.text)) return { text: "Hello! How can I help you today?", actions: STARTER_ACTIONS };
  if (IS_THANKS.test(q.text)) return { text: "You're welcome! Anything else I can help with?", actions: STARTER_ACTIONS };
  if (has(q, ["who are you", "your name", "are you a bot", "are you human", "are you real", "are you a person", "what can you do", "help"]) && q.tokens.length <= 6) {
    return { text: "I'm Krish, GTapex Academy's virtual assistant. I'm not a person, but I can tell you about courses, fees, placement and refunds, or connect you with our team.", actions: STARTER_ACTIONS };
  }
  if (asksForOurDetails.test(raw)) return contactReply();

  if (has(q, ["refund", "money back", "cancel", "cancellation"])) {
    return {
      text: "Online courses: full refund if you ask within 7 days of paying and have completed less than 25% of the lessons.\nOffline courses and programmes: full refund before your first class, 50% within 7 days of it, and none after that.\nNot being placed in a job isn't a reason for a refund.\nYou always get a full refund if you were charged twice, never received access, or GTapex cancels the course.",
      actions: [LINKS.refund, { label: TALK, quick: TALK }],
    };
  }
  if (has(q, ["guarantee", "guaranteed", "assured"])) return placementReply(list);
  if (has(q, ["forgot", "password", "login", "log in", "sign in", "signin"])) {
    return { text: "You can log in from the top of any page. If you've forgotten your password, you can reset it.", actions: [{ label: "Log in", href: "/login" }, { label: "Reset password", href: "/forgot-password" }] };
  }
  if (has(q, ["register", "signup", "sign up", "create account", "create an account", "new account"])) {
    return { text: "You can create a free account in under a minute.", actions: [{ label: "Create account", href: "/register" }] };
  }
  if (has(q, ["demo", "trial", "free class", "free session", "meeting", "appointment", "consultation"])) {
    return { text: "Happy to set that up. A free demo is a short live walkthrough of the course content and platform, with time for your questions. There's no payment or commitment.", actions: [LINKS.demo, { label: "Ask the team to call me", quick: TALK }] };
  }
  if (has(q, ["certificate", "certification", "certified", "certificates"])) {
    return { text: "Yes. When you finish a course, you can download a certificate with a unique ID that anyone can verify.", actions: [LINKS.courses] };
  }
  if (has(q, ["emi", "instalment", "installment", "instalments", "discount", "coupon", "scholarship", "batch", "batches", "timing", "timings", "schedule", "start date", "when does", "when do", "when will", "language", "telugu", "hindi", "tamil", "hostel", "accommodation", "salary", "internship"])) {
    return offerTheTeam();
  }
  if (has(q, ["address", "location", "located", "where are you", "where is your", "office", "visit", "hyderabad", "madhapur", "based"])) {
    return { text: `We're based in Madhapur, Hyderabad. Our office is at ${ADDRESS}. Open ${HOURS}.`, actions: [LINKS.map, LINKS.contact] };
  }
  if (has(q, ["contact", "email", "mail", "number", "call"])) return contactReply();
  if (has(q, ["buy", "purchase", "enroll", "enrol", "join", "admission", "payment", "pay"])) {
    const steps = course
      ? `Open ${course.title}, choose how you want to learn, and click Buy now. You'll be asked to log in first if you haven't already.`
      : "Open the course you want, choose online or offline, and click Buy now. You'll be asked to log in first if you haven't already.";
    return { text: steps, actions: course ? [viewCourse(course), LINKS.refund] : [LINKS.courses, LINKS.refund], courseId: course?.id };
  }

  const asksPrice = has(q, ["price", "prices", "prize", "pricing", "cost", "costs", "fee", "fees", "charge", "charges", "amount", "how much", "kitna", "kitni", "entha", "rate", "rates", "package", "quote", "cheap", "cheapest", "lowest", "budget", "afford", "rupees"]);
  const asksLength = has(q, ["duration", "how long", "how many months", "months", "month", "length", "weeks", "span"]);
  const asksDetail = has(q, ["syllabus", "curriculum", "topics", "learn", "teach", "cover", "covers", "modules", "lessons", "about", "details", "tell me"]);

  if ((asksPrice || asksLength || asksDetail || named) && !courses) return noCourseData();
  if (asksPrice) {
    if (course) return courseSummary(course);
    const sorted = has(q, ["cheap", "cheapest", "lowest", "budget", "afford"]) ? [...list].sort((a, b) => a.price - b.price) : list;
    return sorted.length ? { text: `Here are our fees:\n${sorted.map(feeLine).join("\n")}`, actions: [LINKS.courses, { label: "Help me choose", quick: TALK }] } : noCourseData();
  }
  if (asksLength) {
    if (course) return { text: course.duration_months ? `${course.title} runs for ${length(course)}.` : `I don't have the length of ${course.title}, but our team can confirm it.`, actions: [viewCourse(course), LINKS.specialist], courseId: course.id };
    return list.length ? { text: `Here's how long each course runs:\n${list.map((c) => `• ${c.title}: ${length(c) || "ask our team"}`).join("\n")}`, actions: [LINKS.courses] } : noCourseData();
  }
  if (asksDetail && course) {
    if (course.slug === PLACEMENT) return placementReply(list);
    return { text: `${course.title}: ${course.short_description}\nThe course page shows the full curriculum and fees.`, actions: [viewCourse(course), LINKS.specialist], courseId: course.id };
  }
  if (has(q, ["recommend", "suggest", "best", "which", "should", "confused", "fresher", "beginner", "right for"])) {
    return named ? courseSummary(named) : recommendReply(list);
  }
  if (has(q, ["placement", "placements", "placed", "job", "jobs", "career"])) return placementReply(list);
  if (named) return courseSummary(named);
  if (has(q, ["online", "offline", "classroom", "recorded", "live", "class", "classes", "difference"])) {
    return {
      text: "Online courses include recorded lessons and live classes.\nOffline courses include classroom learning, in-person trainer support and placement assistance, at our office in Madhapur, Hyderabad.\nThe 100% Placement Programme and Entrepreneurship Programme are classroom only.",
      actions: [LINKS.courses, LINKS.map],
    };
  }
  if (has(q, ["course", "courses", "programme", "programmes", "program", "programs", "offer", "available", "list", "what do you"])) {
    return list.length
      ? { text: `We offer ${list.length} courses and programmes:\n${list.map(feeLine).join("\n")}`, actions: [LINKS.courses, { label: "Help me choose", quick: TALK }] }
      : noCourseData();
  }
  return offerTheTeam();
}
