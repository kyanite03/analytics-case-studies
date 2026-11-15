# Australian electricity & emissions dashboard ("choose your path to net zero by 2050").
# Users set the 2050 generation mix; the app recomputes emissions, compares them with
# Paris targets, and maps the forest area needed to offset what remains.

library(ozmaps)
library(sf)
library(shiny)
library(ggplot2)
library(tidyr)
library(dplyr)
library(forcats)


# ---- Static data -------------------------------------------------------------

# Generation by source (TWh): history to 2025, then AEMO 2024 ISP step-change path.
# The 2050 column is replaced by the user's inputs.
energy_data0 <- tibble::tribble(
~Type,                   ~`1990`, ~`1995`, ~`2000`, ~`2005`, ~`2010`, ~`2015`, ~`2020`, ~`2025`, ~`2030`, ~`2035`, ~`2040`, ~`2050`,
"Coal",                 121.167, 138.3541, 174.0335, 181.1663, 179.7928, 158.6098, 146,     120,     38,      14,      7,      5,
"Gas",                  14.359,  14.913,   16.245,   23.8029,  44.5878,  52.9169,  55,      42,      30,      37,      34,     35,
"Wind",                 0.0,     0.007,    0.058,    0.885,    5.0517,   11.4665,  20,      40,      129,     155,     183,    205,
"Solar (incl. Rooftop PV)", 0.0, 0.0189,   0.0435,   0.0778,   0.4745,   5.5313,   21,      55,      98,      125,     149,    180,
"Other",                4.302,   3.666,    2.481,    7.105,    6.3794,   10.5268,  7,       8,       8,       11,      10,     15,
"Hydro & Storage",      14.88,   16.239,   16.7205,  15.6127,  13.5492,  13.4456,  15,      20,      37,      47,      55,     60,
)

# Emission factors (Mt CO2 per TWh generated)
emission_factors <- tibble::tibble(
  Type = c("Coal", "Gas", "Wind", "Solar (incl. Rooftop PV)", "Other", "Hydro & Storage"),
  CO2_per_Twh = c(1.01, 0.49, 0, 0, 0.41, 0)
)

# Non-electricity emissions (Mt CO2), from Australia's Emissions Projections 2024
non_electric_emissions <- data.frame(
  Year = c(1990, 1995, 2000, 2005, 2010, 2015, 2020, 2025, 2030, 2040, 2050),
  emit_non = c(334, 360, 370, 380, 370, 370, 370, 350, 290, 220, 90)
)

# ---- UI ----------------------------------------------------------------------

ui <- fluidPage(
 tags$head(
  tags$style(HTML("
    html, body, .container-fluid {
      height: 100%;
      margin: 0;
      padding: 0;
      font-size: 18px;
    }

    .shiny-input-container {
      font-size: 18px;
      margin-bottom: 12px;
      padding: 6px 10px;
    }

    input[type='number'] {
      height: 40px;
      padding: 6px 10px;
      font-size: 18px;
    }

    .action-button {
      font-size: 18px;
      padding: 8px 16px;
      height: 44px;
    }

    h4 {
      font-size: 28px;
      margin: 0;
    }

    .plot-title {
      font-size: 20px;
    }

    .form-label {
      font-size: 18px;
    }

    .form-control {
      font-size: 18px;
    }
      #total_display {
    font-size: 20px;
    font-weight: bold;
    color: #8B0000;
  }
  "))
),

div(class = "main-container",
  style = "display: flex; flex-direction: column; height: 1080px;",

  div(style = "flex: 0 0 80px; padding: 10px; display: flex; justify-content: space-between; align-items: center;",
  h4("Make Australia Green Again! (Choose your electricity path to net zero by 2050)"),

  div(style = "text-align: right;",
    tags$div("by Kai Marsh", style = "font-size: 16px; font-weight: bold;"),
    actionButton("show_references", "View References")
  )
),
  div(style = "flex: 1 1 auto; padding-top: 10px; display: flex;",  # middle section fills available space
      div(style = "width: 1120px;", plotOutput("energyPlot", height = "750px")),
      
      div(style = "width: 160px; font-size: 18px; margin-left: 20px; overflow-y: auto;",
        strong("Total must equal 500 TWh\n(AEMO, 2024)"),
        textOutput("total_display"),
        numericInput("coal_2050", "Coal (2050)", value = 5),
        numericInput("gas_2050", "Gas (2050)", value = 35),
        numericInput("wind_2050", "Wind (2050)", value = 205),
        numericInput("solar_2050", "Solar (2050)", value = 180),
        numericInput("other_2050", "Other (2050)", value = 15),
        numericInput("hydro_2050", "Hydro & Storage (2050)", value = 60),
        actionButton("submit_2050", "Update")
      ),

      div(style = "width: 600px; margin-left: 10px; margin-right: 10px;", plotOutput("forestMap", height = "750px"))
  ),

  div(style = "flex: 0 0 250px; margin-top: 20px; border-top: 1px solid #ccc; padding-top: 10px;",
    div(style = "display: flex; height: 100%;",
        div(style = "width: 540px;", plotOutput("emissionsBar", height = "100%")),
        div(style = "width: 900px;", plotOutput("projectedEmissionsBar", height = "100%")),
        div(style = "width: 480px;", plotOutput("emissionsCheckBox", height = "100%"))
    )
  )
)
)




# ---- Server ------------------------------------------------------------------

server <- function(input, output, session) {

  # Per-session state: the generation table, updated when the user submits a 2050 mix
  energy_data <- reactiveVal(energy_data0)

  energy_long <- reactive({
    pivot_longer(energy_data(), cols = -Type,
                 names_to = "Year", values_to = "TWh") %>%
      mutate(Year = as.integer(Year)) %>%
      group_by(Type) %>%
      mutate(total_TWh = sum(TWh)) %>%
      ungroup() %>%
      mutate(Type = fct_reorder(Type, total_TWh, .desc = TRUE)) %>%
      dplyr::select(-total_TWh) %>%
      left_join(emission_factors, by = "Type") %>%
      mutate(Emissions = TWh * CO2_per_Twh)
  })

  electricity_emissions <- reactive({
    energy_long() %>%
      group_by(Year) %>%
      summarise(emit_electric = sum(Emissions, na.rm = TRUE))
  })

  emit <- reactive({
    full_join(electricity_emissions(), non_electric_emissions, by = "Year")
  })

  emit_long <- reactive({
    emit() %>%
      pivot_longer(cols = c(emit_electric, emit_non),
                   names_to = "Emission_Type",
                   values_to = "Emissions") %>%
      mutate(Emission_Type = recode(Emission_Type,
                                    emit_electric = "Electricity",
                                    emit_non = "Ex-Electricity"))
  })


# Reference list shown in the "View References" modal
reference_text <- paste0(
  "Data Sources:\n",
  "Australian Energy Market Operator. (2024). Integrated system plan 2024. https://aemo.com.au/-/media/files/major-publications/isp/2024/2024-integrated-system-plan-isp.pdf?la=en",
  "Department of Climate Change, Energy, the Environment and Water. (2024). Australia’s Emissions Projections 2024. Canberra, ACT: Australian Government. https://www.dcceew.gov.au/climate-change/publications/australias-emissions-projections-2024\n",
  "Department of Climate Change, Energy, the Environment and Water. (2024). National Greenhouse Gas Inventory Quarterly Update December 2023. Canberra, ACT: Australian Government.\n",
  "International Energy Agency. (2023). Australia: CO₂ Emissions from Fuel Combustion 1990–2022. Paris: IEA.\n",
  "Climate Action Tracker. (2024). Australia: Country Summary. Retrieved from https://climateactiontracker.org/countries/australia/\n",
  "Syed, A. (2015). Australian Government Energy Projections to 2050. In S. Kimura & H. Phoumin (Eds.), Energy Outlook and Energy Saving Potential in East Asia (pp. 49–68). ERIA Research Project Report 2014-33, Jakarta: ERIA.\n",
  "\n",

  "Libraries:\n",
  "Chang, W., Cheng, J., Allaire, J. J., Xie, Y., & McPherson, J. (2023). shiny: Web Application Framework for R (Version 1.8.0). https://CRAN.R-project.org/package=shiny\n",
  "Wickham, H. (2016). ggplot2: Elegant Graphics for Data Analysis. Springer.\n",
  "Wickham, H., François, R., Henry, L., & Müller, K. (2023). dplyr: A Grammar of Data Manipulation (Version 1.1.4). https://CRAN.R-project.org/package=dplyr\n",
  "Wickham, H., & Henry, L. (2023). tidyr: Tidy Messy Data (Version 1.3.0). https://CRAN.R-project.org/package=tidyr\n",
  "Wickham, H. (2023). forcats: Tools for Working with Categorical Variables (Factors) (Version 1.0.0). https://CRAN.R-project.org/package=forcats\n",
  "Sumner, M. D., & Main, T. (2023). ozmaps: Australia Maps (Version 0.4.1). https://CRAN.R-project.org/package=ozmaps\n",
  "Pebesma, E. (2018). Simple Features for R: Standardized Support for Spatial Vector Data. The R Journal, 10(1), 439–446. https://doi.org/10.32614/RJ-2018-009\n"
)

observeEvent(input$show_references, {
  showModal(modalDialog(
    title = "References (APA 7)",
    pre(reference_text),
    easyClose = TRUE,
    size = "l"
  ))
})

  # Treat empty numeric inputs as 0
  safe_input <- function(x) {
    if (is.null(x) || is.na(x)) 0 else x
  }

  # On "Update": warn if the mix doesn't sum to 500 TWh, then apply it to 2050
  observeEvent(input$submit_2050, {
    total <- sum(sapply(list(input$coal_2050, input$gas_2050, input$wind_2050,
                             input$solar_2050, input$other_2050, input$hydro_2050), safe_input))

if (total != 500) {
  showModal(modalDialog(
    title = tags$div(style = "font-size: 20px;", "Input Error"),
    tags$div(style = "font-size: 16px;", 
             paste("The total must sum to 500 TWh (AEMO, 2024). Your total is", total)),
    easyClose = TRUE,
    footer = modalButton("OK")
  ))
}
  new_2050 <- c(
    "Coal" = safe_input(input$coal_2050),
    "Gas" = safe_input(input$gas_2050),
    "Wind" = safe_input(input$wind_2050),
    "Solar (incl. Rooftop PV)" = safe_input(input$solar_2050),
    "Other" = safe_input(input$other_2050),
    "Hydro & Storage" = safe_input(input$hydro_2050)
  )


  updated <- energy_data()
  updated[["2050"]] <- unname(new_2050[updated$Type])
  energy_data(updated)
  })

  # Stacked generation mix, 1990-2025 history plus the 2050 scenario
  output$energyPlot <- renderPlot({
  df2 <- energy_long()

  df <- df2 %>% filter(Year <= 2025 | Year == 2050)

  # Recode labels for plotting
  df$Type <- recode(df$Type,
    "Solar (incl. Rooftop PV)" = "Solar (incl.\nRooftop PV)",
    "Hydro & Storage" = "Hydro &\nStorage",
    "Coal" = "Coal\n",
    "Wind" = "Wind\n",
    "Other" = "Other\n",
    "Gas" = "Natural\nGas"
  )
  df$Type <- factor(df$Type, levels = rev(c(
    "Coal\n",             # bottom
    "Natural\nGas",
    "Other\n",
    "Hydro &\nStorage",
    "Wind\n",
    "Solar (incl.\nRooftop PV)"  # top
  )))
  energy_colors <- c(
    "Coal\n" = "black",
    "Natural\nGas" = "grey60",
    "Other\n" = "#8B4513",                # brown
    "Hydro &\nStorage" = "#1E90FF",          # dodger blue
    "Wind\n" = "#A9DFBF",                      # light green
    "Solar (incl.\nRooftop PV)" = "#FFF176" # light yellow
  )



  ggplot(df, aes(x = Year, y = TWh, fill = Type)) +
    geom_area(position = "stack", alpha = 0.85) +
    scale_fill_manual(values = energy_colors) +
    scale_x_continuous(
      breaks = seq(1990, 2050, by = 10),
      limits = c(1990, 2050)
    ) +
    labs(title = "Electricity Generation Makeup (Projected to 2050)",
         subtitle = "Measured in Terawatt Hours (TWh)", y="",x = "Year") +
    theme_minimal(base_size = 20) +
    theme(
      legend.title = element_text(size = 18),
      legend.text = element_text(size = 16),
      axis.title = element_text(size = 20),
      axis.text = element_text(size = 16),
      plot.title = element_text(size = 24, face = "bold"),
      legend.key.height = unit(0.6, "lines"),
      legend.spacing.y = unit(0, "lines"),
      legend.margin = margin(t = 2, r = 2, b = 2, l = 2, unit = "pt"),
      plot.margin = margin(5, 5, 5, 5)
    )
})

# Live running total of the 2050 inputs
output$total_display <- renderText({
  total <- sum(sapply(list(input$coal_2050, input$gas_2050, input$wind_2050,
                           input$solar_2050, input$other_2050, input$hydro_2050), safe_input))

  paste("total:", total)
})


output$forestMap <- renderPlot({
  # Offset area needed for 2050 emissions, drawn as a square in central Australia
  aus_sf <- ozmaps::ozmap_states

  total_2050 <- emit_long() %>%
    filter(Year == 2050) %>%
    summarise(total = sum(Emissions, na.rm = TRUE)) %>%
    pull(total)

  cc_per_ha <- 10   # t CO2 sequestered per hectare per year
  hectares_needed <- (total_2050 * 1e6) / cc_per_ha
  area_km2 <- hectares_needed * 0.01
  side_km <- sqrt(area_km2)
  deg_per_km <- 1 / 111
  side_deg <- side_km * deg_per_km

  lon_start <- 129
  lat_start <- -26

  square_coords <- matrix(c(
    lon_start, lat_start,
    lon_start + side_deg, lat_start,
    lon_start + side_deg, lat_start + side_deg,
    lon_start, lat_start + side_deg,
    lon_start, lat_start
  ), ncol = 2, byrow = TRUE)

  square_sf <- st_polygon(list(square_coords)) %>% st_sfc(crs = 4326) %>% st_sf()

  ggplot() +
    geom_sf(data = aus_sf, fill = alpha("#f0e6d2",0.3), color = "black", linewidth = 0.4) +
    geom_sf(data = square_sf, fill = "forestgreen", alpha = 0.4, color = "darkgreen") +
    labs(
      title = "Required Carbon Offset Area on a Map",
      subtitle = paste0("Estimated offset area: ", round(side_km, 1), " km per side\nOffset area = Trees planted at a density of 2000/ha"),
      x = NULL, y = NULL
    ) + 
    theme_minimal() + 
    coord_sf(expand = FALSE, datum = NA) +
    theme(
      axis.text = element_blank(),
      axis.ticks = element_blank(),
      panel.grid = element_blank(),
      plot.margin = margin(0, 0, 0, 0),
      panel.spacing = unit(0, "cm"),
      legend.position = "none",
      plot.title = element_text(
      size = 22,
      hjust = 0.5,
      vjust = 1, face = "bold",
      margin = margin(t = 0, b = 3)),
      plot.subtitle = element_text(
      size = 18,
      hjust = 0.5,
      margin = margin(t = 0, b = 5)
    ),  ) 
})



  # Paris Agreement reference bars
  output$emissionsBar <- renderPlot({
  emissions <- tibble::tibble(
    Year = c("2005 level", "2030 Target", "2050 Target"),
    Emissions = c(611, 428, 0),
    Colour = c("black", "#072d07", "darkgreen"),
    Label = c("611 Mt", "428 Mt", "ZERO")  # Custom label for 2050
  )

  emissions$highlight <- emissions$Year == "2050 Target"

  ggplot(emissions, aes(y = Year, x = Emissions, fill = Colour)) +
    geom_col(width = 0.7) +
    geom_text(aes(label = Label, x = Emissions + 20, 
                  fontface = ifelse(highlight, "bold", "plain"),
                  colour = ifelse(highlight, "darkgreen", "black")),
              hjust = 0, size = 6, show.legend = FALSE) +
    scale_fill_identity() +
    scale_color_identity() +
    labs(
      title = "Paris Agreement Commitments (AU)",
      subtitle = "CO₂ Emissions",
      x = NULL, y = NULL
    ) +
    theme_minimal(base_size = 16) +
    theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      axis.text.y = element_text(
        face = ifelse(emissions$Year == "2050 Target", "bold", "plain"),
        colour = ifelse(emissions$Year == "2050 Target", "darkgreen", "black"),
        size = 14
      )
    ) +
    xlim(0, 700)
})


# Emissions under the user's plan; 2030/2040 electricity interpolated linearly from 2025 to 2050
output$projectedEmissionsBar <- renderPlot({
emit_df <- emit()
non_electric_all <- emit_df %>% dplyr::select(Year, emit_non)

# Calculate electric emissions at 2025 and 2050 for interpolation
elec_2025 <- emit_df %>% filter(Year == 2025) %>% pull(emit_electric)
elec_2050 <- emit_df %>% filter(Year == 2050) %>% pull(emit_electric)
rate_per_year <- (elec_2050 - elec_2025) / (2050 - 2025)
elec_2030 <- elec_2025 + rate_per_year * (2030 - 2025)
elec_2040 <- elec_2025 + rate_per_year * (2040 - 2025)

emit_updated <- emit_df %>%
  mutate(emit_electric = case_when(
    Year == 2030 ~ elec_2030,
    Year == 2040 ~ elec_2040,
    TRUE ~ emit_electric
  ))

# pivot long for plotting
df <- emit_updated %>%
  pivot_longer(cols = c(emit_electric, emit_non),
               names_to = "Emission_Type",
               values_to = "Emissions") %>%
    mutate(
      Emission_Type = recode(Emission_Type,
                             emit_electric = "Electricity",
                             emit_non = "Non-Electricity"),
      Emission_Type = factor(Emission_Type, levels = c("Electricity", "Non-Electricity")),
      highlight = ifelse(Year %in% c(2030, 2040, 2050), "highlight", "normal")
    ) %>%
    filter(Year %in% c(1990, 2005, 2020, 2030, 2040, 2050))

  ggplot(df, aes(x = factor(Year), y = Emissions, fill = Emission_Type)) +
    geom_col(width = 0.6, position = "stack") +
    scale_fill_manual(values = c(
      "Electricity" = "red",
      "Non-Electricity" = "darkgrey"
    )) +
    labs(
      title = "Calculated Emissions*",
      subtitle = "Million Tons of CO₂",
      x = "", y = "", fill = "Source",
      caption = "*Your plan’s electricity emissions, non-electricity emissions taken from government projections"
    ) +
    theme_minimal(base_size = 18) +
    theme(
      legend.position = "right",
      axis.text.x = element_text(face = ifelse(levels(factor(df$Year)) %in% c("2030", "2040", "2050"), "bold", "plain")),
      plot.caption = element_text(size = 9, hjust = 0, margin = margin(t = 10)))
})

  # Pass/fail panel: residual 2050 emissions vs ~100 Mt/yr realistic offset capacity
  output$emissionsCheckBox <- renderPlot({
  df <- emit_long()
  total_2050 <- sum(df$Emissions[df$Year == 2050], na.rm = TRUE)

  met_target <- total_2050 <= 100
  status_text <- if (met_target) {
    "\u2714 Congrats!\nAustralia will meet its\nParis 2050 emissions target."
  } else {
    paste("❌ Sorry, try again.",
          "Aus Gov estimates a maximum\n of 100 Mt CO₂/year\n can be realistically offset via\ncarbon capture.",
          sep = "\n")
  }

  bar_color <- if (met_target) "forestgreen" else "firebrick"

  # Set up blank canvas
  par(mar = c(0.5, 0.5, 0.5, 0.5))
  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0, 1))

  # Draw thick horizontal bars
  rect(0.1, 0.9, 0.9, 1, col = bar_color, border = NA)
  rect(0.1, 0.20, 0.9, 0.1, col = bar_color, border = NA)

  # Draw main status text
  text(0.5, 0.55, status_text, cex = 1.8, font = 2)

  # Show actual emissions number
  text(0.5, 0.03, paste("2050 Emissions:", round(total_2050), "Mt CO₂"), cex = 1.6)
})

}

shinyApp(ui = ui, server = server)