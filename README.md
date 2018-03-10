# LUR_PostGIS_R
## PostGIS scripts for Land Use Regression (LUR)/regression mapping. Generate the LUR variables as seen in almost every LUR study
## R scripts to specify and validate the LUR model.  Also see https://github.com/dwmorley/RLUR for model specification using David's shiny dashboard



It is possible to replicate the process using freely available data.  This example uses French national datasets to create LUR model for NO2. 

 - See Eeftens et al. (2012) for more info on specific variables - Environ. Sci. Technol., 2012, 46 (20), pp 11195–11205 DOI: 10.1021/es301948k
 - Required files are point locations of receptors, land cover polygons (usually CORINE), road geography with traffic flows (not that these data have not been possible to source for France), postcode centroids with population and number of households. These files need to be imported into PostGIS and the relevant filenames renamed in the DECLARE section of each SQL script 
 - Make sure that you are using consistent SRIDs 
 - Intersect air quality monitoring stations with https://www.eea.europa.eu/data-and-maps/data/copernicus-land-monitoring-service-eu-dem and offer this as a variable in the later modelling stages
