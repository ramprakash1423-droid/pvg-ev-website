// Local test receipts only. Production tax invoices must be issued by the accounting provider.
export function receiptPdf(booking) {
  const b=booking.invoice.bill;
  const amount=n=>`INR ${(n/100).toFixed(2)}`;
  const lines=['PVG EV - LOCAL TEST RECEIPT','NO MONEY COLLECTED - NOT A TAX INVOICE','',`Booking: ${booking.reference}`,`Customer: ${booking.customer.name}`,`Vehicle: ${booking.ev.model}`,`Energy: ${(b.energy_milli/1000).toFixed(3)} kWh`,`Energy charge: ${amount(b.energy_paise)}`,`Visit fee: ${amount(b.visit_fee_paise)}`,`Tax (sample configuration): ${amount(b.tax_paise)}`,`Total: ${amount(b.total_paise)}`,`Test payment: ${booking.invoice.payment_status}`,`Customer accepted: ${booking.invoice.accepted_at}`,'','Zoho Books is not connected in this local build.'];
  const escape=s=>s.replace(/[^\x20-\x7e]/g,' ').replace(/[\\()]/g,'\\$&');
  const stream=`BT /F1 12 Tf 48 780 Td 22 TL ${lines.map((line,i)=>`${i?'T* ':''}(${escape(line)}) Tj`).join('\n')} ET`;
  const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',`<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`];
  let output='%PDF-1.4\n';const offsets=[0];
  objects.forEach((object,i)=>{offsets.push(Buffer.byteLength(output));output+=`${i+1} 0 obj\n${object}\nendobj\n`;});
  const xref=Buffer.byteLength(output);output+=`xref\n0 6\n0000000000 65535 f \n${offsets.slice(1).map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('')}trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return Buffer.from(output);
}
