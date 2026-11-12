import { PDFDocument, StandardFonts, rgb, type PDFFont, type PDFPage } from "pdf-lib";

export interface CertificateDetails {
  certificate_code: string; issued_at: string; student_name: string; course_title: string; platform_name: string;
}

const hex = (h: string) => rgb(parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255);
const INDIGO = hex("#4338ca"), SLATE = hex("#334155"), MUTED = hex("#64748b");

/** The standard PDF fonts only cover Western characters; drop anything they cannot draw instead of failing. */
function printable(text: string, font: PDFFont): string {
  try { font.encodeText(text); return text; } catch { /* fall through to per-character check */ }
  return Array.from(text).filter((ch) => { try { font.encodeText(ch); return true; } catch { return false; } }).join("");
}

function centred(page: PDFPage, text: string, y: number, font: PDFFont, size: number, color = SLATE) {
  const t = printable(text, font);
  page.drawText(t, { x: (page.getWidth() - font.widthOfTextAtSize(t, size)) / 2, y, size, font, color });
}

/** A4 landscape certificate, same layout as the old server-side (ReportLab) version. */
export async function renderCertificatePdf(c: CertificateDetails): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  doc.setTitle(`Certificate ${c.certificate_code}`);
  const page = doc.addPage([841.89, 595.28]);
  const w = page.getWidth(), h = page.getHeight();
  const [helv, helvBold, helvOblique, timesBold, timesBoldItalic] = await Promise.all([
    doc.embedFont(StandardFonts.Helvetica), doc.embedFont(StandardFonts.HelveticaBold), doc.embedFont(StandardFonts.HelveticaOblique),
    doc.embedFont(StandardFonts.TimesRomanBold), doc.embedFont(StandardFonts.TimesRomanBoldItalic),
  ]);

  page.drawRectangle({ x: 0, y: 0, width: w, height: h, color: hex("#f8fafc") });
  page.drawRectangle({ x: 24, y: 24, width: w - 48, height: h - 48, borderColor: INDIGO, borderWidth: 6 });
  page.drawRectangle({ x: 38, y: 38, width: w - 76, height: h - 76, borderColor: hex("#c7d2fe"), borderWidth: 1.5 });

  centred(page, c.platform_name.toUpperCase(), h - 100, helvBold, 16, INDIGO);
  centred(page, "Certificate of Completion", h - 170, timesBold, 44);
  centred(page, "This is to certify that", h - 225, helv, 15, MUTED);
  centred(page, c.student_name, h - 280, timesBoldItalic, 38, INDIGO);
  page.drawLine({ start: { x: w / 2 - 190, y: h - 292 }, end: { x: w / 2 + 190, y: h - 292 }, thickness: 1, color: INDIGO });
  centred(page, "has successfully completed the course", h - 328, helv, 15, MUTED);
  centred(page, c.course_title.length <= 60 ? c.course_title : c.course_title.slice(0, 57) + "...", h - 370, helvBold, 24);

  const date = new Intl.DateTimeFormat("en-GB", { day: "2-digit", month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(c.issued_at));
  page.drawText(`Date: ${date}`, { x: 80, y: 90, size: 12, font: helv, color: MUTED });
  const idText = `Certificate ID: ${c.certificate_code}`;
  page.drawText(idText, { x: w - 80 - helv.widthOfTextAtSize(idText, 12), y: 90, size: 12, font: helv, color: MUTED });
  centred(page, `Issued by ${c.platform_name}`, 70, helvOblique, 11, MUTED);
  return doc.save();
}
