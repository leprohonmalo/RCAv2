source("panelProjection.R")
#' Compute Reference Component features for clustering analysis
#'
#' @param rca.obj RCA object.
#' @param method Either "GlobalPanel"(default), "ColonEpitheliumPanel", or "Custom"
#' @param customPath directory path (including filename) to any custom panel stored in RDS format. Only used if method == "Custom".
#' @param corMeth Any of the correlation measures supported by R, defaults to pearson
#' @param power power to raise up to for the RCA features before clustering, default is 4
#' @param scale True if the data should be scaled, False otherwise
#' @param ctSelection A character vector of cell types if not NULL. Only selected cell types will be kept in projection. 
#' @return RCA object.
#' @export
#'
dataProject <- function(rca.obj,
                        method = "GlobalPanel",
                        customPath = NULL,
                        corMeth = "pearson",
                        power = 4,
                        scale = T,
                        ctSelection = NULL) {

    # Extract data
    sc_data <- rca.obj$data

    # If panel for correlation is GlobalPanel
    if (method == "GlobalPanel") {

        # Initialise variable to store projection data from the two fragments of the Global Panel
        projection_list = list()

        # For each fragment of the Global Panel
        for (i in 1:length(ReferencePanel[[1]])) {
            
            # Store projection data of fragment of Global Panel
            projection_list[[i]] = panelProjection(sc_data,
                                                   ReferencePanel[[1]][[i]],
                                                   corMeth=corMeth,
                                                   power=power, scale=scale, 
                                                   apply_threshold=TRUE, 
                                                   threshold=(ReferencePanel$at)[i],
                                                   ctSelection = ctSelection)
        }

        # Combine the projection result of multiple Global Panel fragments
        projection = do.call("rbind", projection_list)

    }
    # If panel for correlation is ColonEpitheliumPanel
    else if (method == "ColonEpitheliumPanel") {
        
        panel = ReferencePanel$ColonEpiPanel
        # Convert rownames to gene symbol and sum duplicates
        gene.names = as.character(str_extract_all(rownames(panel), "_.+_"))
        gene.names = str_sub(gene.names, 2, -2)
        panel = cbind(panel, gene.names)
        dup.genes = unique(gene.names[duplicated(gene.names)])
        for (gene in dup.genes) {
            sub.panel = panel[which(gene.names == gene),1:(ncol(panel) - 1)]
            new.row = apply(sub.panel, MARGIN = 2, FUN = "sum")
            for (i in which(gene.names == gene)) {
                panel[i, 1:(ncol(panel) - 1)] = new.row
            }
        }
        panel = panel[-which(duplicated(panel$gene.names)),]
        rownames(panel) = panel$gene.names
        panel = panel[,-ncol(panel)]
        # Scale panel by median
        fc = apply(panel, 1, function(x) x - median(x))
        fs = fc > 1.5
        panel = panel[apply(fs, 1, function(x)
            sum(x)) > 0,]
        # Store projection data
        projection= panelProjection(sc_data, panel, corMeth=corMeth,
                                    power=power, scale=scale,
                                    ctSelection = ctSelection)
    }
    
    # If any other panel is chosen
    else if (method %in% names(ReferencePanel)) {
        
        panel <- ReferencePanel[[method]]
        
        # Store projection data
        projection= panelProjection(sc_data, panel, corMeth=corMeth,
                                    power=power, scale=scale,
                                    ctSelection = ctSelection)
    }
    
    # If no provided method is chosen, it is assumed that the user wishes to use a custom panel
    else {

        # Load panel from path provided
        panel <- readRDS(customPath)
        
        # Store projection data
        projection = panelProjection(sc_data, panel, corMeth=corMeth,
                                    power=power, scale=scale,
                                    ctSelection = ctSelection)
    }
    
    if (is.null(projection)) {
        print("Not any projection was succesfull for this panel.")
        return(NULL)
    }
    # Store projection result as Matrix
    projection = as.matrix(projection)
    projection = as(projection, "dgCMatrix")

    # Assign projection result to RCA object
    rca.obj$projection.data <- projection

    ### Return RCA object

    return(rca.obj)
}
        