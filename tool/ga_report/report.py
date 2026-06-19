"""Pulls a daily summary from GA4 and emails it.

Requires env vars:
  GA4_PROPERTY_ID            - numeric GA4 property ID
  GOOGLE_APPLICATION_CREDENTIALS - path to a service account JSON key with
                              Viewer access on the GA4 property
  GMAIL_USERNAME              - Gmail address to send from
  GMAIL_APP_PASSWORD          - Gmail App Password for that account
  REPORT_TO_EMAIL             - recipient address
"""

import os
import smtplib
from email.mime.text import MIMEText

from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import (
    DateRange,
    Dimension,
    Metric,
    OrderBy,
    RunReportRequest,
)

PROPERTY_ID = os.environ["GA4_PROPERTY_ID"]
TOP_PAGES_LIMIT = 5


def _client() -> BetaAnalyticsDataClient:
    return BetaAnalyticsDataClient()


def fetch_active_users(client: BetaAnalyticsDataClient) -> dict[str, int]:
    """Active users for yesterday, the trailing 7 days, and the trailing 30 days."""
    ranges = {
        "yesterday": DateRange(start_date="yesterday", end_date="yesterday"),
        "last_7_days": DateRange(start_date="7daysAgo", end_date="yesterday"),
        "last_30_days": DateRange(start_date="30daysAgo", end_date="yesterday"),
    }
    results = {}
    for label, date_range in ranges.items():
        request = RunReportRequest(
            property=f"properties/{PROPERTY_ID}",
            date_ranges=[date_range],
            metrics=[Metric(name="activeUsers")],
        )
        response = client.run_report(request)
        value = 0
        if response.rows:
            value = int(response.rows[0].metric_values[0].value)
        results[label] = value
    return results


def fetch_top_pages(client: BetaAnalyticsDataClient) -> list[dict]:
    """Top pages by views over the trailing 7 days, with avg engagement time."""
    request = RunReportRequest(
        property=f"properties/{PROPERTY_ID}",
        date_ranges=[DateRange(start_date="7daysAgo", end_date="yesterday")],
        dimensions=[Dimension(name="pagePath")],
        metrics=[
            Metric(name="screenPageViews"),
            Metric(name="averageSessionDuration"),
        ],
        order_bys=[
            OrderBy(metric=OrderBy.MetricOrderBy(metric_name="screenPageViews"), desc=True)
        ],
        limit=TOP_PAGES_LIMIT,
    )
    response = client.run_report(request)
    pages = []
    for row in response.rows:
        pages.append(
            {
                "path": row.dimension_values[0].value,
                "views": int(row.metric_values[0].value),
                "avg_duration_seconds": float(row.metric_values[1].value),
            }
        )
    return pages


def format_duration(seconds: float) -> str:
    minutes, secs = divmod(int(seconds), 60)
    return f"{minutes}m {secs:02d}s" if minutes else f"{secs}s"


def build_email_body(active_users: dict, top_pages: list[dict]) -> str:
    lines = [
        "RenderObjects.com — Daily Analytics Summary",
        "",
        "Unique visitors",
        f"  Yesterday:    {active_users['yesterday']}",
        f"  Last 7 days:  {active_users['last_7_days']}",
        f"  Last 30 days: {active_users['last_30_days']}",
        "",
        "Top pages (last 7 days)",
    ]
    if not top_pages:
        lines.append("  No page view data yet.")
    for i, page in enumerate(top_pages, start=1):
        lines.append(
            f"  {i}. {page['path']} — {page['views']} views, "
            f"avg {format_duration(page['avg_duration_seconds'])} on page"
        )
    return "\n".join(lines)


def send_email(body: str) -> None:
    msg = MIMEText(body)
    msg["Subject"] = "RenderObjects.com — Daily Analytics Summary"
    msg["From"] = os.environ["GMAIL_USERNAME"]
    msg["To"] = os.environ["REPORT_TO_EMAIL"]

    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
        server.login(os.environ["GMAIL_USERNAME"], os.environ["GMAIL_APP_PASSWORD"])
        server.send_message(msg)


def main() -> None:
    client = _client()
    active_users = fetch_active_users(client)
    top_pages = fetch_top_pages(client)
    body = build_email_body(active_users, top_pages)
    print(body)
    send_email(body)


if __name__ == "__main__":
    main()
