// Conservative research guidance shared by the dashboard and exported report.
export function coverageReady(data) {
  return (data?.analysis?.coverage || 0) >= 0.8;
}

export function reliableTrait(row, data) {
  return coverageReady(data) && row.posts >= 30 && row.accounts >= 3 && row.recommendable === true;
}

export function ctaGuidance(data) {
  const a = data?.cta_analysis || {};
  const rows = a.groups || [];
  const yes = rows.find(r => r.val === 'with_cta');
  const no = rows.find(r => r.val === 'no_cta');
  const enough = coverageReady(data) && yes?.posts >= 30 && no?.posts >= 30
    && yes?.accounts >= 3 && no?.accounts >= 3 && a.paired_accounts >= 3
    && (yes.posts + no.posts) / (data.analysis.posts || Infinity) >= 0.8;
  if (!enough) return {
    status: 'collecting',
    title: 'A call to action is optional',
    text: 'There is not enough balanced evidence to recommend adding or removing a CTA. Use an explicit action when it serves the post’s goal; a showcase or useful lesson can stand on its own.'
  };
  if (yes.low > no.high && a.paired_difference > 0) return {
    status: 'with_cta', title: 'Test a relevant call to action',
    text: 'CTA posts have a higher observed win rate, with the same direction in comparisons within accounts and formats. Test an action suited to your goal. This association does not prove the CTA caused virality.'
  };
  if (no.low > yes.high && a.paired_difference < 0) return {
    status: 'no_cta', title: 'Test letting the post stand on its own',
    text: 'Posts without a CTA have a higher observed win rate, with the same direction in comparisons within accounts and formats. Try a version with no closing request. This association does not prove removing a CTA caused the result.'
  };
  return {status: 'unclear', title: 'No clear CTA advantage',
    text: 'The comparison does not consistently favor either option. Choose based on your goal, and test both. A keyword giveaway can increase replies without bringing qualified inquiries.'};
}

export function reportName(data, extension = 'html') {
  const date = String(data.generated_at || new Date().toISOString()).slice(0,10);
  const period = data.window_days === 1095 ? 'all-time' : `${data.window_days}d`;
  return `agency-signal-report-${date}-${period}.${extension}`;
}
