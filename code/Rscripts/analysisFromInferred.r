library(scimapClient)
library(rrdf)
library(ggplot2)
library(reshape2)
library(dplyr)

scimapRegister()

setwd("/Users/howison/Documents/UTexas/Projects/SoftwareCitations/softcite/")
#source("code/Rscripts//analysisFromInferred.r")


# Output goes to this file (using print)
sink("output/analysis_output.txt")

inferredData = load.rdf("output/inferredStatements.ttl", format="TURTLE")

prefixes <- paste(readLines("code/Rscripts/sparql_prefixes.sparql", encoding="UTF-8"), collapse=" ")

####################
# Begin with analysis of mentions.
####################

query <- "
SELECT ?article ?journal ?strata ?selection ?mention ?category
WHERE {
	?mention rdf:type bioj:SoftwareMention ;
			 citec:mention_category [ rdfs:label ?category ] ;
   	 		 bioj:from_selection ?selection .
	?article bioj:has_selection ?selection ;
	         dc:isPartOf ?journal .
	?journal bioj:strata ?strata .
}
"

mentions <- data.frame(sparql.rdf(inferredData, paste(prefixes, query, collapse=" ")))

articles_with_mentions <- summarise(mentions, article_count = n_distinct(article))[1,1]

cat("--------------------------\n")
cat("There were ")
cat(articles_with_mentions)
cat(" articles with mentions and ")
cat(90 - articles_with_mentions)
cat( " articles without.\n")

####################
# Which articles have mentions and how many do they have?
####################
cat("--------------\n")
cat("Counts of articles, mentions, and Journals\n")

mentions_by_strata <- mentions %.%
  group_by(strata) %.%
  summarize( journal_count = n_distinct(journal), 
             article_count = n_distinct(article), 
			 mention_count = n_distinct(selection))

print(mentions_by_strata)

cat("--------------\n")
cat("# Percentage of articles with mentions\n")

print(round(mentions_by_strata$article_count / 30,2))

cat("--------------\n")
cat("In total we found ")
cat(summarize(mentions, count = n_distinct(mention))[1,1])
cat(" mentions\n")


####################
#  Mentions by strata boxplot
####################

mention_count_by_article <- mentions %.%
   group_by(strata,article) %.%
   summarize(  mention_count = n_distinct(selection)
   ) %.%
   arrange(desc(mention_count))

ggplot(mention_count_by_article,aes(x=strata,y=mention_count)) + geom_boxplot() + scale_y_continuous(name = "Mentions in article") + scale_x_discrete(name="Journal Impact Factor rank")

ggsave(filename="output/Fig1-MentionsByStrataBoxplot.png", width=5, height=2)

cat("--------------------\n")
cat("Outputted Figure 1: MentionsByStrataBoxplot.png\n")


######################
# Mention classifications
#####################

# melt to vertical format.
mmentions <- melt(mentions, id=1:5)

# Arrange by order
mmentions$value <- factor(mmentions$value,levels=c("Cite to publication", "Cite to user manual", "Cite to name or website", "Like instrument" , "URL in text", "Name only", "Not even name"))

# 
cat("--------------\n")
cat("Table 3. Types of software mentions in publications\n")

total_mentions <- nrow(mentions)

print(mmentions %.%
group_by(value) %.%
summarize(num=n_distinct(mention), percent = round(n_distinct(mention) / total_mentions, 2)))

ggplot(mmentions,aes(x=value)) +
geom_bar() +
#facet_grid(.~strata,margins=T) +
scale_fill_grey(guide = guide_legend(title="")) +
scale_x_discrete(name="") +
scale_y_continuous(name="Count of Mentions") +
#ggtitle("Accessibility by strata") +
theme(legend.position="none",
      panel.grid.major.x = element_blank(),
	panel.grid.minor.y = element_blank(),
	panel.border = element_blank(),
	axis.title.y=element_text(vjust=0.3),
	axis.title.x=element_text(vjust=0.1),
	text=element_text(size=10),
	axis.text.x=element_text(angle=25,hjust=1)
	)

ggsave(filename="output/Fig2-TypesOfSoftwareMentions.png", width=5, height=4)
cat("--------------------\n")
cat("Outputted Figure 2: TypesOfSoftwareMentions.png\n")

####################
# Major mention types by strata.
####################

# Table for software mentions, including proportions
# total_mentions <- n_distinct(mentions$selection)
#
# mentions %.%
# group_by(category) %.%
# summarize(num_type = n_distinct(selection),
#           proportion = round(num_type / total_mentions, 2) ) %.%
# arrange(desc(num_type))

# Want proportions of each type within its strata.

# Get total in strata
mentions_by_strata <- mentions %.% group_by(strata) %.%
summarize(total_in_strata = n_distinct(selection))

#     strata total_in_strata
# 1     1-10             130
# 2   11-110              89
# 3 111-1455              65

# Count number of each category in each strata
types_by_strata <- mentions %.%
group_by(strata, category) %.%
summarize(type_in_strata = n_distinct(selection))

#      strata                category type_in_strata
# 1      1-10 Cite to name or website              2
# 2      1-10     Cite to publication             47
# 6      1-10           Not even name              3
# 7      1-10             URL in text              6
# 8    11-110 Cite to name or website              8
# 9    11-110     Cite to publication             34

# Add the total for that strata to each row, to be used to create percentage
types_by_strata <- merge(types_by_strata,mentions_by_strata)

# create the percentage for each row.
types_by_strata <- within(types_by_strata, proportion <- round(type_in_strata / total_in_strata, 2))

# This would give you a usable table to show these data
# dcast(types_by_strata, category ~ strata , sum, value.var="type_in_strata")

# reduce to just the 'major categories
types_for_graph <- filter(types_by_strata, category %in% c("Cite to publication","Like instrument","Name only"))

# Then graph as dodged bars
ggplot(types_for_graph,aes(x=strata,y=proportion,fill=strata)) + 
  geom_bar(stat="identity") + 
  facet_grid(.~category) + 
  scale_y_continuous(name="Proportion",limits=c(0,0.5)) +
  scale_x_discrete(name="Strata") +
  scale_fill_grey() + 
  theme(legend.position="none",
        panel.grid.major.x = element_blank(),
		panel.grid.minor.y = element_blank(),
		panel.border = element_blank(),
		axis.title.y=element_text(vjust=0.3),
		axis.title.x=element_text(vjust=0.1),
		text=element_text(size=10),
		axis.text.x=element_text(angle=25,hjust=1)) +
#  ggtitle("Major software mention types by journal strata")
  
ggsave(filename="output/Fig3-MentionTypesByStrata.png", width=5, height=4)
cat("--------------------\n")
cat("Outputted Figure 3: MentionTypesByStrata.png\n")

###################
# Summary of software mentioned
###################

query <- "
SELECT ?article_link ?article ?software ?software_name
WHERE {
	?article_link rdf:type bioj:ArticleSoftwareLink ;
	              bioj:mentions_software ?software ;
				  bioj:from_article ?article .
	?software rdfs:label ?software_name .
}
"

software_with_names <- data.frame(sparql.rdf(inferredData, paste(prefixes, query, collapse=" ")))

software_in_articles <- software_with_names %.%
group_by(software_name) %.%
summarize(article_count = n_distinct(article))

cat("--------------------\n")
cat("Most used software\n")

most_used <- software_in_articles %.%
#filter(article_count > 1) %.%
arrange(desc(article_count))

cat(paste(most_used$software_name, collapse="\n"))
cat("\n\n")
cat(paste(most_used$article_count, collapse="\n"))




query <- "
SELECT DISTINCT ?software
WHERE {
	?software rdf:type bioj:SoftwarePackage .
}
"

software_packages <- data.frame(sparql.rdf(inferredData, paste(prefixes, query, collapse=" ")))


cat("--------------------\n")
cat("We found references to ")
cat(nrow(software_packages))
cat(" distinct pieces of software\n")

# Then analysis of ArticleSoftwareLinks (identifiable/findable/credited)

query <- "
SELECT DISTINCT ?software_article_link
WHERE {
	?software_article_link rdf:type bioj:ArticleSoftwareLink .
}
"

article_links <- data.frame(sparql.rdf(inferredData, paste(prefixes, query, collapse=" ")))


cat("--------------------\n")
cat("there are  ")
cat(nrow(article_links))
cat("  unique combinations of software and articles\n")



query <- "
SELECT ?article ?journal ?strata ?software_article_link ?credited ?findable ?identifiable ?versioned ?version_findable
WHERE {
	?software_article_link 	rdf:type bioj:ArticleSoftwareLink ;
							citec:is_credited       ?credited ;
							citec:is_findable       ?findable ;
							citec:is_identifiable   ?identifiable ;
							citec:is_versioned      ?versioned ;
							citec:version_is_findable ?version_findable ;
	 						bioj:from_article ?article . 
	?article dc:isPartOf ?journal .
	?journal bioj:strata ?strata .
}
"
#
links <- data.frame(sparql.rdf(inferredData, paste(prefixes, query, collapse=" ")))

# Convert to %
# get totals
links_by_strata <- links %.% group_by(strata) %.%
summarize(total_in_strata = n_distinct(software_article_link))

# melt to vertical format.
mlinks <- melt(links, id=1:4)

# Count number of each category in each strata
link_counts <- mlinks %.%
group_by(strata,variable,value) %.%
summarize(count = n())

# Add the total for that strata to each row, to be used to create percentage
links_by_strata <- merge(links_by_strata,link_counts)

# create the percentage for each row.
links_by_strata <- within(links_by_strata, proportion <- round(count / total_in_strata, 2))

cat("--------------------\n")
cat("ArticleSoftwareLinks and credited, findable, identifiable\n")
print(dcast(filter(links_by_strata, value=="true"),variable ~ strata , mean , value.var="proportion", margins="strata"))

has_version_info <- nrow(filter(links,versioned == "true"))

versions_found <- nrow(filter(links,versioned == "true" & version_findable == "true"))[1]

cat("\nprovided any version information: ")
cat(has_version_info)
cat(" percent: ")
cat(round(has_version_info/nrow(article_links),2))
cat("\n")
cat("provided any version information and could be found: ")
cat(versions_found)
cat(" percent: ")
cat(round(versions_found/nrow(article_links),2))
cat("\n")


# # order factors
# mlinks$variable <- factor(mlinks$variable,levels=c("identifiable","findable","credited"))
# mlinks$value <- factor(mlinks$value,levels=c("true","false"))
# # #
# ggplot(mlinks,aes(x=variable,fill=value)) +
# geom_bar() +
# facet_grid(.~strata,margins=F) +
# scale_fill_grey(guide = guide_legend(title="")) +
# scale_x_discrete(name="") +
# scale_y_continuous(name="Count of Software Article tuples") +
# #ggtitle("Accessibility by strata") +
# theme(
# 	legend.position="bottom",
#     panel.grid.major.x = element_blank(),
# 	panel.grid.minor.y = element_blank(),
# 	panel.border = element_blank(),
# 	axis.title.y=element_text(vjust=0.3),
# 	#axis.title.x=element_text(vjust=0.1),
# 	text=element_text(size=10)
# #	axis.text.x=element_blank(),
# #	axis.ticks.x=element_blank()
#  )
#
# mlinks %.%
# filter(variable=="version") %.%
# group_by(value) %.%
# summarize(num=n_distinct(software_article_link))
#
# mlinks %.%
# filter(variable=="version_findable"|variable=="version") %.%
# group_by(variable) %.%
# summarize(num=n_distinct(software_article_link))
#
# mlinks %.%
# summarize(num=n_distinct(software_article_link))
#
# total_mentions = summarize(mlinks, n_distinct(software_article_link))[1,1]
#
# mlinks %.%
# filter(value=="true") %.%
# group_by(variable) %.%
# summarize(num=n_distinct(software_article_link),
# 	      percent=round( num / total_mentions, 2 ) )
#
#
##################
# Software analysis
# a                               bioj:SoftwarePackage ;
# rdfs:label                      "Macclade" ;
# bioj:mentioned_in               citec:a2007-27-CLADISTICS-C03-mention ;
# citec:is_accessible             true ;
# citec:is_explicitly_modifiable  false ;
# citec:is_free                   true ;
# citec:is_source_accessible      false .
#################
query <- "
SELECT ?strata ?software ?accessible ?modifiable ?source ?free
WHERE {
	?software	rdf:type                        bioj:SoftwarePackageUsed ;
				bioj:mentioned_in	[ bioj:article_software_link [ bioj:from_article [ dc:isPartOf [ bioj:strata ?strata ]]]];
				citec:is_accessible             ?accessible  ;
				citec:is_explicitly_modifiable  ?modifiable  ;
				citec:is_source_accessible      ?source      .
	OPTIONAL { ?software citec:is_free          ?free  }
				
}
"

#[ bioj:from_article ]

software <- data.frame(sparql.rdf(inferredData, paste(prefixes, query, collapse=" ")))
#
# # melt to vertical format.
msoftware <- melt(software, id=1:2)
#
total_software = summarize(msoftware, n_distinct(software))[1,1]

cat("--------------------\n")
cat("there are  ")
cat(total_software)
cat("  software packages used across our paper sample\n")

#
print(msoftware %.%
filter(value=="true") %.%
group_by(variable) %.%
summarize(num=n_distinct(software),
	      percent=round( num / total_software, 2 ) ))

# Do these across strata, but need totals in strata.
# Get total in strata
software_by_strata_totals <- software %.% group_by(strata) %.%
summarize(total_in_strata = n_distinct(software))

#     strata total_in_strata
# 1     1-10             130
# 2   11-110              89
# 3 111-1455              65

# Count number of each category in each strata
software_by_strata <- msoftware %.%
filter(value=="true") %.%
group_by(variable,strata) %.%
summarize(software_in_strata = n_distinct(software))

#      strata                category type_in_strata
# 1      1-10 Cite to name or website              2
# 2      1-10     Cite to publication             47
# 6      1-10           Not even name              3
# 7      1-10             URL in text              6
# 8    11-110 Cite to name or website              8
# 9    11-110     Cite to publication             34

# Add the total for that strata to each row, to be used to create percentage
software_by_strata <- merge(software_by_strata,software_by_strata_totals)

# create the percentage for each row.
software_by_strata <- within(software_by_strata, proportion <- software_in_strata / total_in_strata)

software_by_strata$variable <- factor(software_by_strata$variable, levels=c("accessible","free","source","modifiable"))



software_summary <- dcast(software_by_strata, variable ~ strata , mean , value.var="proportion", margins="strata")


print(software_summary)

ggplot(software_by_strata, aes(x=variable,y=proportion,fill=variable)) + 
  geom_bar(stat="identity") + 
  facet_grid(~strata) + 
  scale_fill_grey(name="",start=0.1,end=0.5) +
  theme(legend.position="bottom",
        legend.text = element_text(size=14),
        panel.grid.major.x = element_blank(),
		panel.grid.minor.y = element_blank(),
		panel.border = element_blank(),
		axis.title.y=element_text(vjust=0.3),
		axis.title.x=element_blank(),
		text=element_text(size=10),
		axis.text.x=element_blank(),
		axis.ticks.x=element_blank()
		)

ggsave(filename="output/Fig4-FunctionsByStrataBoxplot.png", width=5, height=4)

########################
# Misses/Matches preferred citation
########################

query <- "
SELECT ?strata ?article ?software_article_link ?software ?preferred
WHERE {
	?software_article_link 	rdf:type bioj:ArticleSoftwareLink ;
							citec:includes_preferred_cite ?preferred ;
							bioj:mentions_software ?software ;
							bioj:from_article ?article . 
	?article dc:isPartOf ?journal .
	?journal bioj:strata ?strata .
}
"
#
links_preferred <- data.frame(sparql.rdf(inferredData, paste(prefixes, query, collapse=" ")))

cat("--------------------\n")
cat("Preferred citation counts\n\n")

# How many pieces of software are here?
print(summarize(links_preferred,num_software = n_distinct(software), num_links = n_distinct(software_article_link),num_articles=n_distinct(article)))

print(links_preferred %.%
group_by(preferred) %.%
summarize(count = n(), percent = round(n()/nrow(links_preferred),2),num_articles=n_distinct(article)))

cat("--------------------\n")
cat("Appendix 1 table")
query <- "
SELECT ?strata ?title ?policy
WHERE {
  ?journal rdf:type bioj:journal ;
          dc:title ?title ;
          bioj:strata ?strata ;
		  citec:has_software_policy ?policy .
}
"
journals <- data.frame(sparql.rdf(inferredData, paste(prefixes, query, collapse=" ")))

cat("\n\n--------------------\n")
cat("1-10\n")
j <- journals %.% filter(strata == "1-10") %.% select(title)
cat(paste(j$title,collapse="\n"))

cat("\n\n--------------------\n")
cat("11-110\n")
j <- journals %.% filter(strata == "11-110") %.% select(title)
cat(paste(j$title,collapse="\n"))

cat("\n\n--------------------\n")
cat("111-1455\n")
j <- journals %.% filter(strata == "111-1455") %.% select(title)
cat(paste(j$title,collapse="\n"))

journal_totals <- journals %.% group_by(strata) %.%
summarize(total_in_strata = n_distinct(title))

# Count number of each category in each strata
journals_by_strata <- journals %.%
filter(policy=="true") %.%
group_by(strata) %.%
summarize(policy_in_strata = n_distinct(title))


# Add the total for that strata to each row, to be used to create percentage
journals_by_strata <- merge(journals_by_strata,journal_totals)

# create the percentage for each row.
journals_by_strata <- within(journals_by_strata, proportion <- round(policy_in_strata / total_in_strata, 2))

cat("\n\n--------------------\n")
cat("Percentage of journals with software citation guidelines\n")

print(journals_by_strata)
cat("Overall : ")
cat(round(sum(journals_by_strata$policy_in_strata) / sum(journals_by_strata$total_in_strata),2))



sink()
closeAllConnections()
