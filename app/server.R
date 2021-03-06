source("global.R") 

if (interactive()){
shinyServer(function(input,output, session){
  
  #page<-read_html("https://github.com/nychealth/coronavirus-data/blob/master/summary.csv")
  #num<-page%>%
  #  html_nodes("td")%>%html_text()
  
  output$time<-renderText({
    paste0("Last Updated: ",as.character(quick_update$NUMBER_OF_NYC_RESIDENTS[quick_update["MEASURE"]=="DATE_UPDATED"])) #"time"
    }) #paste("Date Updated:",num[16])
  
  output$total<- renderValueBox({
    valueBox(#num[4],
      prettyNum(quick_update$NUMBER_OF_NYC_RESIDENTS[quick_update["MEASURE"]=="NYC_CASE_COUNT"],big.mark = ','),
      subtitle = "Total Cases",
      icon = icon("stethoscope"),
      color = "maroon")
  })
  
  output$hosp<- renderValueBox({
    
    valueBox(#num[7],
      prettyNum(quick_update$NUMBER_OF_NYC_RESIDENTS[quick_update["MEASURE"]=="NYC_HOSPITALIZED_COUNT"],big.mark = ','),
      subtitle = "Total Hospitalized",
      icon = icon("plus"),
      color = "yellow")
  })
  
  output$death<- renderValueBox({
    valueBox(#num[10],
      prettyNum(quick_update$NUMBER_OF_NYC_RESIDENTS[quick_update["MEASURE"]=="NYC_CONFIRMED_DEATH_COUNT"],big.mark = ',')
      ,subtitle = "Total Deaths",
      icon = icon("heart-broken"),
      color = "navy")
  })
  
  # ------ Table in Map part ----------------
  staticRender_cb <- JS('function(){debugger;HTMLWidgets.staticRender();}') 
  output$recentTable <- renderDataTable(recent_use_dat,
                                        escape = FALSE,
                                        options = list(drawCallback = staticRender_cb))
  
  # -------- Restaurant Map -----------------
  # filtered data for zooming in specific borough in the map
  filtered_data_map <- reactive({
    if(is.null(input$boro)){selected_boro = levels(res_map$borough)}
    else{selected_boro = input$boro}
    res_map %>%
      filter(borough %in% selected_boro)
    })
  
  
  # restaurant Map
  output$resMap <- renderLeaflet({
    leaflet(res_map, options = leafletOptions(minZoom = 10, maxZoom = 18)) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lng = -73.95, lat = 40.72, zoom = 10) %>%
      addMarkers(lng = res_map$longitude, lat = res_map$latitude,
                 clusterOptions = markerClusterOptions(),
                 label = lapply(
                   lapply(seq(nrow(res_map)), function(i){
                     paste0('<b>',res_map[i, "name"], '</b>', '<br/>', 
                            'Address: ',res_map[i, "address"], '<br/>',
                            'Zipcode: ',res_map[i, "postcode"], '<br/>',
                            'Seating: ',res_map[i, "seating"],'<br/>',
                            'Alcohol: ',res_map[i, "alcohol"]) }), htmltools::HTML)) 
    })
  
  
  observe({
    temp_df = filtered_data_map()
    leafletProxy('resMap',data = temp_df) %>%
      fitBounds(~min(longitude), ~min(latitude), ~max(longitude), ~max(latitude)) %>%
      clearMarkerClusters()%>%
      clearMarkers() %>%
      addMarkers(lng = temp_df$longitude, lat = temp_df$latitude,
                 clusterOptions = markerClusterOptions(),
                 label = lapply(
                   lapply(seq(nrow(temp_df)), function(i){
                     paste0('<b>',temp_df[i, "name"], '</b>', '<br/>', 
                            'Address: ',temp_df[i, "address"], '<br/>',
                            'Zipcode: ',temp_df[i, "postcode"], '<br/>',
                            'Seating: ',temp_df[i, "seating"],'<br/>',
                            'Alcohol: ',temp_df[i, "alcohol"]) }), htmltools::HTML)) 
    })
  
  
  # --------- Restaurant Report --------------------
  # filtered data for count number of restaurants by borough
  filtered_restaruant <- reactive({
    if(is.null(input$boro1)){selected_boro = levels(res_dat_distinct$borough)}
    else{selected_boro = input$boro1}
    res_dat_distinct %>%
      filter(borough %in% selected_boro)})
  
  # number of open restaurants
  output$resNum <- renderValueBox({
    valueBox(
      prettyNum(nrow(filtered_restaruant()), big.mark = ','), "Open Restaurants",
      icon=icon("utensils", lib="font-awesome"), 
      color = "olive"
    )
  })
  
  # group by alcohol service
  output$resAlco <- renderValueBox({
    valueBox(
      prettyNum(sum(filtered_restaruant()$alcohol=='yes'), big.mark = ','),
      "Alcohol Service",
      icon=icon("cocktail", lib="font-awesome"),
      color="yellow"
      
    )

  })
  
  # pie chart, group by seating type
  output$seating_pie <- renderHighchart({
    filtered_restaruant() %>%
      group_by(seating) %>%
      count() %>%
      hchart('pie', hcaes(x=seating, y=n))
  })
  
  # number of reopen restaurants by borough
  output$resCountBoro <- renderHighchart({
    res_dat_distinct %>%
      group_by(borough) %>%
      count() %>%
      hchart('column',hcaes(x=borough,y=n,color=borough)) %>%
      hc_plotOptions(column = list(
        dataLabels = list(enabled = F),
        enableMouseTracking = T )) %>%
      hc_yAxis(title = list(text = "Number of Restaurants")) %>%
      hc_xAxis(title = list(text = ""))
  })
  
  # number of reopen restaurants by alcohol service & by borough
  output$resByAlco <- renderHighchart({
    res_dat_distinct %>%
      mutate(al2 = case_when(alcohol=='yes'~'Alcohol Served',alcohol=='no'~'No Alcohol Served')) %>%
      group_by(borough, al2) %>%
      count() %>%
      group_by() %>%
      hchart('column', hcaes(x='borough', y='n', group='al2'), stacking='normal') %>%
      hc_yAxis(title = list(text = "Number of Restaurants")) %>%
      hc_xAxis(title = list(text = "")) %>%
      hc_legend( layout = 'vertical', align = 'right', verticalAlign = 'top')
  })
  
  # number of reopen restaurants by seating type & by borough
  output$resBySeat <- renderHighchart({
    res_dat_distinct %>%
      group_by(borough, seating) %>%
      count() %>%
      group_by() %>%
      hchart('column', hcaes(x='borough', y='n', group='seating'), stacking='normal') %>%
      hc_yAxis(title = list(text = "Number of Restaurants")) %>%
      hc_xAxis(title = list(text = "")) %>%
      hc_legend( layout = 'vertical', align = 'right', verticalAlign = 'top')
  })
  
  # reopen application time series
  output$resTS <- renderHighchart({
    res_dat_distinct %>%
      mutate(date = as.Date(time_submit, '%m/%d/%Y')) %>%
      group_by(date) %>%
      count() %>%
      hchart('line', hcaes(x=date,y=n)) %>%
      hc_yAxis(title = list(text = "Number of Applications")) %>%
      hc_xAxis(title = list(text = "")) %>%
      hc_rangeSelector( enabled=TRUE, buttons = list(
        list(type = 'all', text = 'All'),
        list(type = 'day', count = 13, text = 'Indoor'),
        list(type = 'day', count = 85, text = 'Ph4'),
        list(type = 'day', count = 99, text = 'Ph3'),
        list(type = 'day', count = 115, text = 'Ph2')
      ))
  })
  
  output$caseResBoroBar <- renderPlotly({
    case_res_bar
  })
  
  output$boroPhase <- renderPlotly({boro_phase
    })
  
  output$resAnimation <- renderImage({
    list(src = "./output/rest_boro_ani.gif",
         contentType = 'image/gif')
  },deleteFile=FALSE)
  
  output$caseAnimation <- renderImage({
    list(src = "./output/case_boro_ani.gif",
         contentType = 'image/gif')
  },deleteFile=FALSE)
  
  # -------- Plots Comparing Manhattan and the Bronx Map Cases by Age-----------  
  age_input <- reactive({
    if(is.null(input$age_group)){age_input ="65-74"}
    else{age_input = input$age_group}
  })

 
  output$case_age_Bx <- renderLeaflet({
      # Color palette
      pal <- colorNumeric(
        palette = "YlGnBu",
        domain = 0:7000
      )
      leaflet(bronxBorder, options = leafletOptions(minZoom = 10, maxZoom = 18))%>%
      setView(lng=-73.8648, lat=40.8448, zoom = 11)%>%
      addTiles()%>%
      addProviderTiles(providers$CartoDB.Positron)%>%
      addPolygons(
        fillColor = ~pal(boros_by_age$BX_CASE_RATE[boros_by_age$group==age_input()]),
        weight =2, opacity = 1,color = 'white',fillOpacity = 0.7,
        highlight = highlightOptions( weight = 5,color = "#666",fillOpacity = 0.7,
                                      bringToFront = TRUE),
        label= HTML(
          "Case Rate of Age Range in Boro: ",boros_by_age$BX_CASE_RATE[boros_by_age$group==age_input()],'<br/>',
          "Age Range: ", age_input()
        )
      )%>%
      leaflet::addLegend(pal=pal,
                values = 0:7000,
                opacity =0.7, 
                title=htmltools::HTML("Case Rate of Age<br>
                                      Group in Neighborhood"),
                position ='bottomright')
        
  })
  
  output$case_age_Mn <- renderLeaflet({
    # Color palette
    pal <- colorNumeric(
      palette = "YlGnBu",
      domain = 0:7000
    )
    leaflet(manBorder, options = leafletOptions(minZoom = 10, maxZoom = 18))%>%
      setView(lng=-73.9712, lat=40.7831, zoom = 11)%>%
      addTiles()%>%
      addProviderTiles(providers$CartoDB.Positron)%>%
      addPolygons(
        fillColor = ~pal(boros_by_age$MN_CASE_RATE[boros_by_age$group==age_input()]),
        weight =2, opacity = 1,color = 'white',fillOpacity = 0.7,
        highlight = highlightOptions( weight = 5,color = "#666",fillOpacity = 0.7,
                                      bringToFront = TRUE),
        label= HTML(
          "Case Rate of Age Range in Boro: ",boros_by_age$MN_CASE_RATE[boros_by_age$group==age_input()],'<br/>',
          "Age Range: ", age_input()
        )
      )%>%
      leaflet::addLegend(pal=pal,
                values = 0:7000,
                opacity =0.7, 
                title=htmltools::HTML("Case Rate of Age<br>
                                      Group in Neighborhood"),
                position ='bottomright')
    
  })
  
  
  # -------- Plots Comparing Manhattan and the Bronx Map Cases by Zip----------- 
  output$case_4week_Mn<- renderLeaflet({
    # Color palette
    pal <- colorNumeric(
      palette = "YlOrRd",
      domain =0:200
    )
    # Make labels for zipcodes 
    labels <- lapply(
      lapply(seq(nrow(manZip)), function(i){
        paste0('<b>', manZip[i, "NEIGHBORHOOD_NAME"], "</b>", "<br/>",
               "Covid Case Count in Past 4 Weeks: ", recentMn[i, "COVID_CASE_COUNT_4WEEK"]) }), htmltools::HTML)
      
    leaflet(manZcB, options = leafletOptions(minZoom = 10, maxZoom = 18))%>%
      setView(lng=-73.9712, lat=40.7831, zoom = 11)%>%
      addTiles()%>%
      addProviderTiles(providers$CartoDB.Positron)%>%
      addPolygons(
        fillColor = ~pal(recent_cases$COVID_CASE_COUNT_4WEEK),
        weight =2,
        opacity = 1, 
        color = 'white',
        fillOpacity = 0.7,
        highlight = highlightOptions(
          weight = 5,
          color = "#666",
          fillOpacity = 0.7,
          bringToFront = TRUE),
        label= labels)%>%
      leaflet::addLegend(pal=pal,
                values = 0:200,
                opacity =0.7,
                title=htmltools::HTML("Covid Case Count <br>
                                      in Past 4 Weeks:<br>
                                      by ZCTA"),
                position ='topleft')
    
  })
  
  output$case_4week_Bx <- renderLeaflet({
    # Color palette
    pal <- colorNumeric(
      palette = "YlOrRd",
      domain = 0:200
    )
    # Make labels for zipcodes 
    labels <- lapply(
      lapply(seq(nrow(bronxZip)), function(i){
        paste0('<b>', bronxZip[i, "NEIGHBORHOOD_NAME"], "</b>", "<br/>",
               "Covid Case Count in Past 4 Weeks: ", recentBx[i, "COVID_CASE_COUNT_4WEEK"]) }), htmltools::HTML)
    
    leaflet(bxZcB, options = leafletOptions(minZoom = 10, maxZoom = 18))%>%
      setView(lng=-73.8971, lat=40.8432, zoom = 11)%>%
      addTiles()%>%
      addProviderTiles(providers$CartoDB.Positron)%>%
      addPolygons(
        fillColor = ~pal(recent_cases$COVID_CASE_COUNT_4WEEK),
        weight =2,
        opacity = 1, 
        color = 'white',
        fillOpacity = 0.7,
        highlight = highlightOptions(
          weight = 5,
          color = "#666",
          fillOpacity = 0.7,
          bringToFront = TRUE),
        label= labels)%>%
      leaflet::addLegend(pal=pal,
                values = 0:200,
                opacity =0.7,
                title=htmltools::HTML("Covid Case Count <br>
                                      in Past 4 Weeks:<br>
                                      by ZCTA"),
                position ='topleft')
    
  })
  
  
  # Cases per poverty group
  output$case_by_pov <-renderPlotly({
    
    rate_by_pov
  })

  # Amounts of restaurants in each zipcode
  
  output$res_amt_Mn <- renderLeaflet({
    # Color palette
    pal <- colorNumeric(
      palette = "BuPu",
      domain = amount_res$amount
    )
    # Make labels for zipcodes 
    labels <- lapply(
      lapply(seq(nrow(manZip)), function(i){
        paste0('<b>', manZip[i, "NEIGHBORHOOD_NAME"], "</b>", "<br/>",
               "Covid Case Count in Past 4 Weeks: ", amount_res_Mn[i, "amount"]) }), htmltools::HTML)
    
    leaflet(manZcB, options = leafletOptions(minZoom = 10, maxZoom = 18))%>%
      setView(lng=-73.9712, lat=40.7831, zoom = 11)%>%
      addTiles()%>%
      addProviderTiles(providers$CartoDB.Positron)%>%
      addPolygons(
        fillColor = ~pal(amount_res_Mn$amount),
        weight =2,
        opacity = 1, 
        color = 'white',
        fillOpacity = 0.7,
        highlight = highlightOptions(
          weight = 5,
          color = "#666",
          fillOpacity = 0.7,
          bringToFront = TRUE),
        label= labels)%>%
      leaflet::addLegend(pal=pal,
                values = amount_res$amount,
                opacity =0.7,
                title=htmltools::HTML("Amount of Restaurants<br>
                                      by ZCTA"),
                position ='topleft')
    
  })
  
  output$res_amt_Bx <- renderLeaflet({
    # Color palette
    pal <- colorNumeric(
      palette = "BuPu",
      domain = amount_res$amount
    )
    # Make labels for zipcodes 
    labels <- lapply(
      lapply(seq(nrow(bronxZip)), function(i){
        paste0('<b>', bronxZip[i, "NEIGHBORHOOD_NAME"], "</b>", "<br/>",
               "Covid Case Count in Past 4 Weeks: ", amount_res_Bx[i, "amount"]) }), htmltools::HTML)
    
    leaflet(bxZcB, options = leafletOptions(minZoom = 10, maxZoom = 18))%>%
      setView(lng=-73.8971, lat=40.8432, zoom = 11)%>%
      addTiles()%>%
      addProviderTiles(providers$CartoDB.Positron)%>%
      addPolygons(
        fillColor = ~pal(amount_res_Mn$amount),
        weight =2,
        opacity = 1, 
        color = 'white',
        fillOpacity = 0.7,
        highlight = highlightOptions(
          weight = 5,
          color = "#666",
          fillOpacity = 0.7,
          bringToFront = TRUE),
        label= labels)%>%
      leaflet::addLegend(pal=pal,
                values = amount_res$amount,
                opacity =0.7,
                title=htmltools::HTML("Amount of Restaurants<br>
                                      by ZCTA"),
                position ='topleft')
    
  })
  
})
}
