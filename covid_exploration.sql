/* 
This file uses data from Our World in Data: https://github.com/owid/covid-19-data/tree/master/public/data
In this file I perform some initial explanatory analysis of Covid data, focusing on mortality and vaccination rates
In particular, I want to extract tables showing vaccination rates over time to check for correlation with mortality rates
*/

-- First inspect the case and deaths data
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM portfolio.covid_deaths
ORDER BY 1, 2
LIMIT 100
;

-- What is the mortality rate in different countries?
SELECT 
	location, 
	date,
	total_cases,
	total_deaths, 
	CASE 
		WHEN total_cases IS NULL OR total_deaths IS NULL THEN NULL
		ELSE LEAST(100*(total_deaths/total_cases),100) 
	END AS mortality
FROM portfolio.covid_deaths
WHERE location = 'France'
ORDER BY date
;
/* 
This shows the mortality rate from covid in Ireland rising to an initial peak at 6.7%, before falling away to a
long-term stable rate of around 0.5% starting in early 2022.

It also shows that some countries (e.g. France) reported more deaths than cases early on in the pandemic, giving 
mortality rates over 100%. There's a few ways of dealing with this: given that I'm interested in the relationship 
between mortality and vaccination rates, and vaccines only started rolling out toward the end of 2020, I'm comfortable 
that suppressing erroneous values won't cause any problems. In later analysis I'll set a cap on mortality at 100%.
*/

-- What is the total infection rate in different countries?
-- This is just the number of cases per capita (doesn't account for the same person testing positive multiple times)
SELECT location, MAX(total_cases), (MAX(total_cases)/population)*100 as perc_infected
FROM portfolio.covid_deaths
GROUP BY location, population
ORDER BY perc_infected DESC
;
-- This shows Ireland's infection rate is 34.5%, a little higher than the average for high income countries

-- What countries have the highest total and per capita death counts?
SELECT location, MAX(total_deaths) as death_count, (MAX(total_deaths)/population)*100 as perc_mortality
FROM portfolio.covid_deaths
WHERE continent IS NOT NULL 
GROUP BY location, population
HAVING MAX(total_deaths) IS NOT NULL
ORDER BY perc_mortality DESC
;

-- What's going on with Hong Kong?
SELECT * FROM portfolio.covid_deaths
WHERE location = 'Hong Kong'
;
-- Hong Kong publishes test data monthly and doesn't publish cases or deaths, so the Covid Deaths table is empty.


-- Join with the vaccination table and calculate vaccination rate
WITH vacc_rate AS 
(SELECT d.continent, d.location, death.date, d.population, v.new_vaccinations,
	SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS cumul_vaccines
FROM portfolio.covid_deaths AS d
JOIN portfolio.covid_vaccines AS v
ON d.location = v.location
AND d.date = v.date
WHERE d.continent IS NOT NULL AND d.location = 'Ireland'
)
SELECT *, cumul_vaccines/population as vaccines_per_pop
FROM vacc_rate
;
/*
Ireland's Covid mortality rate stabilised in early 2022, around the same time that most of the population had received
a second vaccine. This might suggest an inflection point in the relationship between vaccines per person and mortality
rate. However, it could also be due to changes in behaviour, lockdown restrictiions etc. We should test this relationship
in other countries that had different vaccine rollout timelines and lockdown rules.
*/
DROP VIEW IF EXISTS portfolio.vacc_mortality;
CREATE VIEW portfolio.vacc_mortality AS
SELECT d.continent, 
	d.location, 
	d.date, 
	d.population, 
	d.total_cases, 
	d.total_deaths, 
	CASE 
		WHEN d.total_cases IS NULL OR d.total_deaths IS NULL THEN NULL
		ELSE LEAST(100,100*(d.total_deaths/d.total_cases))
	END AS mortality,
	v.new_vaccinations,
	SUM(v.new_vaccinations) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS cumul_vaccines
FROM portfolio.covid_deaths AS d
JOIN portfolio.covid_vaccines AS v
ON d.date = v.date AND d.location = v.location
WHERE d.continent IS NOT NULL
;
SELECT *, cumul_vaccines/population AS vaccines_per_pop
FROM portfolio.vacc_mortality
WHERE location = 'Germany'
;