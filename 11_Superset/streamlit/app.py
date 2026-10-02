"""A small dashboard over the same PostgreSQL view used by Superset."""

import os

import pandas as pd
import psycopg
from psycopg.rows import dict_row
import streamlit as st

st.set_page_config(page_title="Supermarket sales", layout="wide")


@st.cache_data(ttl=60)
def load_sales() -> pd.DataFrame:
    """Read a bounded classroom dataset; cache it for one minute per app process."""
    # 'db' is the Compose service name. 'localhost' inside this container would
    # mean the Streamlit container itself, not the PostgreSQL container.
    with psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
    ) as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            # The shared view already joins the fact and dimension tables.
            # SQL reads only; viz_reader has no permission to change records.
            cursor.execute(
                """
                SELECT sale_date, region, category, quantity, sales_amount
                FROM analytics.sales_enriched
                ORDER BY sale_date, region, category
                """
            )
            rows = cursor.fetchall()

    sales = pd.DataFrame(rows)
    sales["sale_date"] = pd.to_datetime(sales["sale_date"])
    sales["sales_amount"] = sales["sales_amount"].astype(float)
    return sales


st.title("Supermarket sales overview")
st.write(
    "Explore fictional sales observations from July to September 2026. "
    "Gross sales means the sum of `sales_amount`; it is not profit."
)

sales = load_sales()
all_regions = sorted(sales["region"].unique().tolist())
all_categories = sorted(sales["category"].unique().tolist())

# Widgets return the current selection. Streamlit reruns this script whenever
# the student changes a widget; all numbers and charts below then update.
selected_regions = st.sidebar.multiselect(
    "Regions", all_regions, default=all_regions
)

# TASK 6: Replace the next line with the category multiselect shown in README.
# The app is usable now: it starts with every category selected.
selected_categories = all_categories

# Keep only rows included by both sidebar selections.
visible = sales[
    sales["region"].isin(selected_regions)
    & sales["category"].isin(selected_categories)
]

if visible.empty:
    st.info("Choose at least one region and one category to see sales.")
    st.stop()

# Metric and chart use the same filtered rows, so they should agree with a
# Superset dashboard when the same filters and date range are selected.
gross_sales = visible["sales_amount"].sum()
st.metric("Gross sales (€)", f"{gross_sales:,.2f}")

daily_sales = visible.groupby("sale_date", as_index=False)["sales_amount"].sum()
st.subheader("Gross sales by day")
st.line_chart(
    daily_sales, x="sale_date", y="sales_amount",
    x_label="Date", y_label="Gross sales (€)",
)

by_category = (
    visible.groupby("category", as_index=False)["sales_amount"]
    .sum()
    .sort_values("sales_amount", ascending=False)
)
st.subheader("Gross sales by category")
st.bar_chart(
    by_category, x="category", y="sales_amount", sort="-sales_amount",
    x_label="Category", y_label="Gross sales (€)",
)

with st.expander("Show the rows behind these charts"):
    st.dataframe(
        visible[["sale_date", "region", "category", "quantity", "sales_amount"]],
        hide_index=True,
        use_container_width=True,
    )

st.caption(
    f"Historical teaching snapshot: {sales['sale_date'].min():%d %b %Y}–"
    f"{sales['sale_date'].max():%d %b %Y}. "
    "This date range is not a live loading status."
)
