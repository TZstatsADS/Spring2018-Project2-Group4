if (!require("DT")) install.packages('DT')
if (!require("dtplyr")) install.packages('dtplyr')
if(!require("lubridate")) install.packages('lubridate')
library(shiny)
library(shinythemes)
library(shinydashboard)
library(dplyr)
library(leaflet)
library(maps)
library(DT)
library(dtplyr)
library(lubridate)

##########################Load Data###############################
Recommendation <- read.csv("../data/Recommendation.csv", header = T, stringsAsFactors = F)
Rank1 <- Recommendation[12:21, ]
Rank2 <- Recommendation[1:10, ]

####################Calculate Distance(Peifeng Hong#######################

##function calculating the distance of start points and sites
Pi <- 3.14159
distcalculate <- function(startlat,startlon,destlat,destlon){
  
  angle <- sin(startlat)*sin(destlat) + cos(startlat)*cos(destlat)*cos(startlon-destlon)
  
  distance <-  6378.137*acos(angle)*Pi/180
  
  return( round(distance,digits = 2))
}

##dataset
sitesdataset <- read.csv("../data/alldata.csv",stringsAsFactors = F)


##############Shiny Server##############

shinyServer(function(input, output, session){
  
  #################Explore page#######################
  
  # Choose Radius(Peifeng Hong)
  
  ##starting point ( to be changed )
  
  find_geom <- function(x){
    output <- geocode(x, output = "latlona")[,c(1,2)]
    output$type <- "start"
    output$name <- x
    output[,"X"] <- 30000
    return(output)
  }
  
  start <- reactive({
    as.data.frame(find_geom(input$variable))
  })

  startlat <-  40.80754
  startlon <-  -73.96257
  
  #distance to start point
  disttosites <- rep(NA,nrow(sitesdataset))
  for (i in 1:nrow(sitesdataset))
    disttosites[i] <- distcalculate(startlat,startlon,sitesdataset$latitude[i],sitesdataset$longtitude[i])
  
  
  siteswithinrange_rec <- reactive({
    siteswithinrange <- filter(data.frame(sitesdataset,
                                          dist = disttosites),disttosites < input$DIST, type %in% input$type)
    siteswithinrange})
  
  observe({print(siteswithinrange_rec()[1,])})
  ##dataset with name 
  output$table <- DT::renderDataTable(siteswithinrange_rec()[,c("name","type","dist")],server = T)

  # delete  
  output$sitestogo <- renderPrint({
    cat('\nSelected Sites\n')
    print(siteswithinrange_rec()[input$table_rows_selected,])
  })  
  
  # to be moved above
  library(TSP)
  
  # routeplan to update numeric x y
  routeplan<-function(df,startpoint){
    f_dis<-function(x,y){
      r=6371
      x=as.numeric(x)*pi/180;y=as.numeric(y)*pi/180
      a=c(cos(x[2])*cos(x[1]),cos(x[2])*sin(x[1]),sin(x[2]))
      b=c(cos(y[2])*cos(y[1]),cos(y[2])*sin(y[1]),sin(y[2]))
      cosg=sum(a*b)/sqrt(sum(a^2)*sum(b^2))
      dis=r*acos(cosg)
      return(dis)
    }
    k<-cbind(df$longtitude,df$latitude)
    len<-nrow(df)
    dis_mat<-matrix(NA,len,len)
    for (i in 1:len){
      for(j in 1:len){
        dis_mat[i,j]=f_dis(k[i,],k[j,])
      }
    }
    colnames(dis_mat)<-rownames(dis_mat)<-df$X
    tsp<-TSP(dis_mat)
    tour<-solve_TSP(tsp,method="2-opt")
    path<-as.integer(tour)
    tour_length(tsp,tour)
    tsp_map<-df[path,]
    line<-tsp_map$X
    c1<-line[which(line==startpoint):length(line)]
    c2<-line[1:which(line==startpoint)]
    route<-c(as.vector(c1), as.vector(c2))
    return(route)
  }
  
  # output$orderofsites <- renderPrint({
  #   cat('\norder of Sites\n')
  #   startpoint <- c(30000,startlon,  startlat,"start",  "start")
  # 
  #   dfsites <- rbind(startpoint,siteswithinrange_rec()[input$table_rows_selected,])
  #  # print(dfsites) 
  #   orderofsites <- as.vector(routeplan(dfsites,30000))
  #   print(orderofsites)
  # }) 
  
  output$orderofsites <- renderPrint({
    cat('\norder of Sites\n')
    startpoint <- c(30000,startlon,  startlat,"start",  "start")
    dfsites <- rbind(startpoint,siteswithinrange_rec()[input$table_rows_selected,])
    orderofsites <- as.vector(routeplan(dfsites,30000))
    
    col <- NULL
    for (i in 1:length(orderofsites)){
      col[i] <- which(dfsites$X==orderofsites[i])
      
    }
    route_name <- dfsites[as.vector(col),]$name
    nn <- nrow(route_name)
    print(as.data.frame(route_name))
    #  print(route_df)
  })
  
  # output$map <- renderLeaflet({
  #   leaflet() %>%
  #     addTiles(group = "OSM") %>%
  #     setView(lng = -73.935242,lat = 40.730610,zoom = 12) %>%
  #     addCircleMarkers(lng = as.numeric(start()$lon),
  #                      lat = as.numeric(start()$lat),
  #                      color = "red",
  #                      stroke = FALSE,
  #                      radius = 6,
  #                      fillOpacity = 0.8)
  # })
    
  # output$map <- renderLeaflet({
  # if (!isolate(input$table_rows_selected))
  #      (route_df <- data.frame(startlon,startlat))
  #  else
  #  {
  #   startpoint <- c(30000,startlon,  startlat,"start",  "start")
  #   route_df <- data.frame(longtitude = startlon,latitude = startlat)
  #   dfsites <- rbind(startpoint,siteswithinrange_rec()[input$table_rows_selected,])
  #   orderofsites <- as.vector(routeplan(dfsites,30000))
  # 
  # 
  #   col <- NULL
  #   for (i in 1:length(orderofsites)){
  #   col[i] <- which(dfsites$X==orderofsites[i])
  # 
  # }
  # route_df <- dfsites[as.vector(col),c(2,3)]
  # nn <- nrow(route_df)
  # 
  # leaflet() %>%
  #   addTiles(group = "OSM") %>%
  #   #setView(lng = startlon,lat = startlat,zoom = 12) %>%
  #   setView(lng = -73.935242,lat = 40.730610,zoom = 12) %>%
  #   addMarkers(lng = as.numeric(route_df$longtitude),
  #                    lat = as.numeric(route_df$latitude))%>%
  #   addCircleMarkers(lng = as.numeric(start()$lon),
  #                  lat = as.numeric(start()$lat),
  #                  color = "red",
  #                  stroke = FALSE,
  #                  radius = 6,
  #                  fillOpacity = 0.8)
  # }})
  
  output$map <- renderLeaflet({

    startpoint <- c(30000,startlon,  startlat,"start",  "start")
    route_df <- data.frame(longtitude = startlon,latitude = startlat)
    dfsites <- rbind(startpoint,siteswithinrange_rec()[input$table_rows_selected,])
    orderofsites <- as.vector(routeplan(dfsites,30000))


    col <- NULL
    for (i in 1:length(orderofsites)){
      col[i] <- which(dfsites$X==orderofsites[i])

    }
    route_df <- dfsites[as.vector(col),c(2,3)]
    nn <- nrow(route_df)

    leaflet() %>%
      addTiles(group = "OSM") %>%
      setView(lng = -73.96257, lat = 40.7580, zoom = 12) %>%
      addCircleMarkers(lng = as.numeric(route_df$longtitude),
                       lat = as.numeric(route_df$latitude))
  })
  ###############Recommendation Page(Fangbing Liu)##################
  
  #The top 10 tourist attractions rank
  output$Rank1 <- renderDataTable({
    
    datatable(Rank1[, c("Rank", "Name")], rownames = FALSE)%>% formatStyle(
      'Name', 
      target = 'row', color = 'black', backgroundColor = 'lightpurple')
  }, server = TRUE)
  
  #Map
  output$maprec1 <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      setView(lng = -73.9712, lat = 40.7580, zoom = 12) %>%
      addMarkers(lng = as.numeric(Rank1$longitude),
                 lat = as.numeric(Rank1$latitude),
                 popup = paste("<b>Rank:</b>", Rank1$Rank, "<br>",
                               "<b>Name:</b>", Rank1$Name, "<br>",
                               "<b>Address:</b>", Rank1$Address, "<br>",
                               "<b>Description:</b>", Rank1$Description)) %>%
      addPopups(lng = as.numeric(Rank1$longitude[input$Rank1_rows_selected]),
                lat = as.numeric(Rank1$latitude[input$Rank1_rows_selected]),
                popup = paste("<b>Rank:</b>", Rank1$Rank[input$Rank1_rows_selected], "<br>",
                              "<b>Name:</b>", Rank1$Name[input$Rank1_rows_selected], "<br>",
                              "<b>Address:</b>", Rank1$Address[input$Rank1_rows_selected], "<br>",
                              "<b>Description:</b>", Rank1$Description[input$Rank1_rows_selected]))
  })
  
  #Top 10 Restaurant rank
  output$Rank2 <- renderDataTable({
    
    datatable(Rank2[, c("Rank", "Name")], rownames = FALSE)%>% formatStyle(
      'Name', 
      target = 'row', color = 'black', backgroundColor = 'lightpurple')
  }, server = TRUE)
  
  #Map
  output$maprec2 <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      setView(lng = -73.9712, lat = 40.7500, zoom = 13) %>%
      addMarkers(lng = as.numeric(Rank2$longitude),
                 lat = as.numeric(Rank2$latitude),
                 popup = paste("<b>Rank:</b>", Rank2$Rank, "<br>",
                               "<b>Name:</b>", Rank2$Name, "<br>",
                               "<b>Address:</b>", Rank2$Address, "<br>",
                               "<b>Description:</b>", Rank2$Description)) %>%
      addPopups(lng = as.numeric(Rank2$longitude[input$Rank2_rows_selected]),
                lat = as.numeric(Rank2$latitude[input$Rank2_rows_selected]),
                popup = paste("<b>Rank:</b>", Rank2$Rank[input$Rank2_rows_selected], "<br>",
                              "<b>Name:</b>", Rank2$Name[input$Rank2_rows_selected], "<br>",
                              "<b>Address:</b>", Rank2$Address[input$Rank2_rows_selected], "<br>",
                              "<b>Description:</b>", Rank2$Description[input$Rank2_rows_selected]))
  })
})