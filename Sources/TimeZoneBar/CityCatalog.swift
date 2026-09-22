import Foundation

struct CatalogEntry: Identifiable, Hashable {
    let id: String
    let display: String      // "Tokyo" / "ET"
    let region: String       // "Asia" / "Eastern Time · New York"
    let timeZoneID: String
    let rank: Int            // lower sorts first in the default list
    let terms: String        // lowercased haystack for search
    let isStandard: Bool     // a named zone abbreviation rather than a city

    init(id: String, display: String, region: String, timeZoneID: String,
         rank: Int, terms: String, isStandard: Bool = false) {
        self.id = id
        self.display = display
        self.region = region
        self.timeZoneID = timeZoneID
        self.rank = rank
        self.terms = terms
        self.isStandard = isStandard
    }

    var subtitle: String {
        // Standard zones already say what they are; don't repeat the abbreviation.
        if isStandard { return region }
        guard let tz = TimeZone(identifier: timeZoneID),
              let abbr = CityCatalog.abbreviation(for: tz) else { return region }
        return "\(region) · \(abbr)"
    }
}

enum CityCatalog {

    /// Named time zone abbreviations. These always sort above cities in search results.
    /// Each maps to a geographic zone so daylight saving is handled correctly — add "ET"
    /// and you get EST or EDT depending on the date. `extraTerms` catches the seasonal
    /// spellings and other names people type.
    /// (abbreviation, description, zone, extraTerms)
    private static let standards: [(String, String, String, String)] = [
        ("UTC",  "Coordinated Universal Time · no DST",   "UTC",                    "utc zulu z gmt0 universal"),
        ("GMT",  "Greenwich Mean Time · UTC+0, no DST",   "GMT",                    "gmt greenwich zulu"),
        ("ET",   "Eastern Time · New York",               "America/New_York",       "et est edt eastern new york toronto"),
        ("CT",   "Central Time · Chicago",                "America/Chicago",        "ct cst cdt central chicago dallas"),
        ("MT",   "Mountain Time · Denver",                "America/Denver",         "mt mst mdt mountain denver"),
        ("PT",   "Pacific Time · Los Angeles",            "America/Los_Angeles",    "pt pst pdt pacific los angeles california"),
        ("AKT",  "Alaska Time · Anchorage",               "America/Anchorage",      "akt akst akdt alaska anchorage"),
        ("HST",  "Hawaii Time · Honolulu",                "Pacific/Honolulu",       "hst hawaii honolulu"),
        ("AT",   "Atlantic Time · Halifax",               "America/Halifax",        "at ast adt atlantic halifax"),
        ("NT",   "Newfoundland Time · St John’s",         "America/St_Johns",       "nt nst ndt newfoundland st johns"),
        ("BST",  "UK Time · London",                      "Europe/London",          "bst gmt+1 uk britain british london england"),
        ("CET",  "Central European Time · Paris",          "Europe/Paris",           "cet cest central european paris berlin amsterdam"),
        ("WET",  "Western European Time · Lisbon",         "Europe/Lisbon",          "wet west western european lisbon"),
        ("EET",  "Eastern European Time · Athens",         "Europe/Athens",          "eet eest eastern european athens helsinki"),
        ("TRT",  "Türkiye Time · Istanbul",                "Europe/Istanbul",        "trt turkey turkiye istanbul ankara"),
        ("MSK",  "Moscow Time",                            "Europe/Moscow",          "msk moscow russia"),
        ("IST",  "India Standard Time · Kolkata",          "Asia/Kolkata",           "ist india indian kolkata mumbai delhi bengaluru"),
        ("NPT",  "Nepal Time · Kathmandu",                 "Asia/Kathmandu",         "npt nepal kathmandu"),
        ("PKT",  "Pakistan Time · Karachi",                "Asia/Karachi",           "pkt pakistan karachi lahore"),
        ("AST",  "Arabia Standard Time · Riyadh",          "Asia/Riyadh",            "ast arabia arabian riyadh saudi"),
        ("GST",  "Gulf Standard Time · Dubai",             "Asia/Dubai",             "gst gulf dubai uae emirates abu dhabi"),
        ("IDT",  "Israel Time · Tel Aviv",                 "Asia/Jerusalem",         "idt ist israel jerusalem tel aviv"),
        ("ICT",  "Indochina Time · Bangkok",               "Asia/Bangkok",           "ict indochina bangkok thailand hanoi"),
        ("WIB",  "Western Indonesian Time · Jakarta",      "Asia/Jakarta",           "wib indonesia jakarta"),
        ("SGT",  "Singapore Time",                         "Asia/Singapore",         "sgt singapore"),
        ("PHT",  "Philippine Time · Manila",               "Asia/Manila",            "pht phst philippines manila"),
        ("CST",  "China Standard Time · Shanghai",         "Asia/Shanghai",          "cst china chinese shanghai beijing"),
        ("HKT",  "Hong Kong Time",                         "Asia/Hong_Kong",         "hkt hong kong"),
        ("JST",  "Japan Standard Time · Tokyo",            "Asia/Tokyo",             "jst japan japanese tokyo osaka"),
        ("KST",  "Korea Standard Time · Seoul",            "Asia/Seoul",             "kst korea korean seoul"),
        ("AWST", "Australian Western Time · Perth",        "Australia/Perth",        "awst australia western perth"),
        ("ACST", "Australian Central Time · Adelaide",     "Australia/Adelaide",     "acst acdt australia central adelaide"),
        ("AEST", "Australian Eastern Time · Sydney",       "Australia/Sydney",       "aest aedt australia eastern sydney melbourne"),
        ("NZST", "New Zealand Time · Auckland",            "Pacific/Auckland",       "nzst nzdt new zealand auckland wellington"),
        ("WAT",  "West Africa Time · Lagos",               "Africa/Lagos",           "wat west africa lagos nigeria"),
        ("CAT",  "Central Africa Time · Harare",           "Africa/Harare",          "cat central africa harare"),
        ("EAT",  "East Africa Time · Nairobi",             "Africa/Nairobi",         "eat east africa nairobi kenya"),
        ("SAST", "South Africa Time · Johannesburg",       "Africa/Johannesburg",    "sast south africa johannesburg cape town"),
        ("BRT",  "Brasília Time · São Paulo",              "America/Sao_Paulo",      "brt brt brasilia brazil sao paulo rio"),
        ("ART",  "Argentina Time · Buenos Aires",          "America/Argentina/Buenos_Aires", "art argentina buenos aires"),
        ("CLT",  "Chile Time · Santiago",                  "America/Santiago",       "clt clst chile santiago"),
        ("COT",  "Colombia Time · Bogotá",                 "America/Bogota",         "cot colombia bogota"),
        ("PET",  "Peru Time · Lima",                       "America/Lima",           "pet peru lima"),
    ]

    /// How many standard zones to list when the search box is empty.
    static let standardPreviewCount = 12

    // MARK: - Zone abbreviations

    // `TimeZone.abbreviation()` is no use here: with a European locale it returns "GMT-5" for
    // New York and "GMT+9" for Tokyo, only giving real names to European zones. So the
    // abbreviations come from the standards table above instead.
    //
    // These are the *generic* forms — ET rather than EST/EDT, CET rather than CET/CEST —
    // which is both what people write and what stays correct when you scrub across a daylight
    // saving boundary.

    /// Mid-winter and mid-summer instants used to fingerprint a zone's DST behaviour.
    /// Recomputed per launch so the fingerprints don't go stale as years pass.
    private static let probes: (jan: Date, jul: Date) = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let year = cal.component(.year, from: Date())
        let jan = cal.date(from: DateComponents(year: year, month: 1, day: 15, hour: 12))
        let jul = cal.date(from: DateComponents(year: year, month: 7, day: 15, hour: 12))
        return (jan ?? Date(), jul ?? Date())
    }()

    /// A zone's winter and summer offsets, which together identify its DST rules.
    private static func offsetFingerprint(_ tz: TimeZone) -> String {
        "\(tz.secondsFromGMT(for: probes.jan))/\(tz.secondsFromGMT(for: probes.jul))"
    }

    /// Zones whose DST fingerprint is shared with another standard, so the inference below
    /// can't name them safely. Pinned by hand rather than left blank.
    private static let extraAbbreviations: [String: String] = [
        "Europe/Kyiv": "EET",             // shares (+2, +3) with Israel
        "Africa/Cairo": "EET",            // same
        "Europe/Dublin": "GMT",           // Ireland's own IST would collide with India's
        "America/Buenos_Aires": "ART",    // legacy alias of America/Argentina/Buenos_Aires
        "Asia/Ho_Chi_Minh": "ICT",        // shares (+7, +7) with Jakarta
        "Australia/Brisbane": "AEST",     // no DST, so it doesn't match Sydney's fingerprint
        "America/Mexico_City": "CST",     // no DST, so it doesn't match Chicago's
        "Asia/Taipei": "CST",             // shares (+8, +8) with several others
    ]

    /// Exact zone → abbreviation, from the standards table, then the pinned extras.
    private static let abbreviationByZone: [String: String] = {
        var m: [String: String] = [:]
        for (abbr, _, zone, _) in standards where m[zone] == nil { m[zone] = abbr }
        for (zone, abbr) in extraAbbreviations where m[zone] == nil { m[zone] = abbr }
        return m
    }()

    /// Every abbreviation the app recognises as a zone name in its own right.
    private static let abbreviationNames: Set<String> = {
        Set(standards.map(\.0)).union(extraAbbreviations.values)
    }()

    /// True when a row's name is itself a zone abbreviation, e.g. a row added from the
    /// standard-zones section. Those rows don't need the label repeated beside them.
    static func isAbbreviationName(_ name: String) -> Bool {
        abbreviationNames.contains(name.uppercased())
    }

    /// DST fingerprint → abbreviation, so cities sharing a standard zone's rules inherit its
    /// name: Berlin picks up CET from Paris, Toronto picks up ET from New York.
    ///
    /// Only fingerprints belonging to exactly one standard are kept. London and Lisbon are
    /// both (0, +1h) but are BST and WET, so that pattern is ambiguous and left out rather
    /// than guessed at — those two are covered by the exact map above anyway.
    private static let abbreviationByFingerprint: [String: String] = {
        var candidates: [String: Set<String>] = [:]
        for (abbr, _, zone, _) in standards {
            guard let tz = TimeZone(identifier: zone) else { continue }
            candidates[offsetFingerprint(tz), default: []].insert(abbr)
        }
        return candidates.compactMapValues { $0.count == 1 ? $0.first : nil }
    }()

    /// The generic abbreviation for a zone — "ET", "CET", "JST" — or nil when there isn't a
    /// recognised one. Returning nil is deliberate: falling back to "GMT+7" would just repeat
    /// what the offset badge already says.
    static func abbreviation(for tz: TimeZone) -> String? {
        abbreviationByZone[tz.identifier] ?? abbreviationByFingerprint[offsetFingerprint(tz)]
    }

    /// Cities that get top billing when the search box is empty.
    private static let featured: [String] = [
        "Europe/Amsterdam", "Europe/London", "Europe/Berlin", "Europe/Paris", "Europe/Madrid",
        "Europe/Lisbon", "Europe/Dublin", "Europe/Brussels", "Europe/Zurich", "Europe/Stockholm",
        "Europe/Warsaw", "Europe/Athens", "Europe/Istanbul", "Europe/Kyiv", "Europe/Moscow",
        "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
        "America/Toronto", "America/Vancouver", "America/Mexico_City", "America/Sao_Paulo",
        "America/Bogota", "America/Buenos_Aires", "America/Santiago", "America/Lima",
        "Asia/Dubai", "Asia/Tokyo", "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Singapore",
        "Asia/Seoul", "Asia/Kolkata", "Asia/Jakarta", "Asia/Bangkok", "Asia/Manila",
        "Asia/Karachi", "Asia/Jerusalem", "Asia/Riyadh", "Asia/Taipei", "Asia/Ho_Chi_Minh",
        "Australia/Sydney", "Australia/Melbourne", "Australia/Perth", "Australia/Brisbane",
        "Pacific/Auckland", "Africa/Lagos", "Africa/Cairo", "Africa/Johannesburg",
        "Africa/Nairobi", "Africa/Casablanca", "Africa/Accra",
        // UTC and GMT deliberately absent — they live in the standard-zones section.
    ]

    /// Well-known cities that don't have their own tz identifier, plus handy nicknames.
    /// (display, region, timeZoneID)
    private static let aliases: [(String, String, String)] = [
        ("Silicon Valley", "United States", "America/Los_Angeles"),
        ("San Francisco", "United States", "America/Los_Angeles"),
        ("Seattle", "United States", "America/Los_Angeles"),
        ("Portland", "United States", "America/Los_Angeles"),
        ("San Diego", "United States", "America/Los_Angeles"),
        ("Las Vegas", "United States", "America/Los_Angeles"),
        ("Austin", "United States", "America/Chicago"),
        ("Dallas", "United States", "America/Chicago"),
        ("Houston", "United States", "America/Chicago"),
        ("New Orleans", "United States", "America/Chicago"),
        ("Nashville", "United States", "America/Chicago"),
        ("Minneapolis", "United States", "America/Chicago"),
        ("Kansas City", "United States", "America/Chicago"),
        ("Salt Lake City", "United States", "America/Denver"),
        ("Boulder", "United States", "America/Denver"),
        ("Washington DC", "United States", "America/New_York"),
        ("Boston", "United States", "America/New_York"),
        ("Philadelphia", "United States", "America/New_York"),
        ("Atlanta", "United States", "America/New_York"),
        ("Miami", "United States", "America/New_York"),
        ("Orlando", "United States", "America/New_York"),
        ("Charlotte", "United States", "America/New_York"),
        ("Pittsburgh", "United States", "America/New_York"),
        ("Cleveland", "United States", "America/New_York"),
        ("Raleigh", "United States", "America/New_York"),
        ("Ottawa", "Canada", "America/Toronto"),
        ("Montreal", "Canada", "America/Toronto"),
        ("Quebec City", "Canada", "America/Toronto"),
        ("Calgary", "Canada", "America/Edmonton"),
        ("Rotterdam", "Netherlands", "Europe/Amsterdam"),
        ("The Hague", "Netherlands", "Europe/Amsterdam"),
        ("Utrecht", "Netherlands", "Europe/Amsterdam"),
        ("Eindhoven", "Netherlands", "Europe/Amsterdam"),
        ("Groningen", "Netherlands", "Europe/Amsterdam"),
        ("Antwerp", "Belgium", "Europe/Brussels"),
        ("Ghent", "Belgium", "Europe/Brussels"),
        ("Leuven", "Belgium", "Europe/Brussels"),
        ("Bruges", "Belgium", "Europe/Brussels"),
        ("Liège", "Belgium", "Europe/Brussels"),
        ("Manchester", "United Kingdom", "Europe/London"),
        ("Edinburgh", "United Kingdom", "Europe/London"),
        ("Glasgow", "United Kingdom", "Europe/London"),
        ("Bristol", "United Kingdom", "Europe/London"),
        ("Birmingham", "United Kingdom", "Europe/London"),
        ("Leeds", "United Kingdom", "Europe/London"),
        ("Cambridge", "United Kingdom", "Europe/London"),
        ("Oxford", "United Kingdom", "Europe/London"),
        ("Cardiff", "United Kingdom", "Europe/London"),
        ("Belfast", "United Kingdom", "Europe/London"),
        ("Munich", "Germany", "Europe/Berlin"),
        ("Hamburg", "Germany", "Europe/Berlin"),
        ("Frankfurt", "Germany", "Europe/Berlin"),
        ("Cologne", "Germany", "Europe/Berlin"),
        ("Düsseldorf", "Germany", "Europe/Berlin"),
        ("Stuttgart", "Germany", "Europe/Berlin"),
        ("Leipzig", "Germany", "Europe/Berlin"),
        ("Lyon", "France", "Europe/Paris"),
        ("Marseille", "France", "Europe/Paris"),
        ("Bordeaux", "France", "Europe/Paris"),
        ("Toulouse", "France", "Europe/Paris"),
        ("Nice", "France", "Europe/Paris"),
        ("Barcelona", "Spain", "Europe/Madrid"),
        ("Valencia", "Spain", "Europe/Madrid"),
        ("Seville", "Spain", "Europe/Madrid"),
        ("Bilbao", "Spain", "Europe/Madrid"),
        ("Palma", "Spain", "Europe/Madrid"),
        ("Milan", "Italy", "Europe/Rome"),
        ("Turin", "Italy", "Europe/Rome"),
        ("Naples", "Italy", "Europe/Rome"),
        ("Florence", "Italy", "Europe/Rome"),
        ("Bologna", "Italy", "Europe/Rome"),
        ("Venice", "Italy", "Europe/Rome"),
        ("Porto", "Portugal", "Europe/Lisbon"),
        ("Geneva", "Switzerland", "Europe/Zurich"),
        ("Basel", "Switzerland", "Europe/Zurich"),
        ("Lausanne", "Switzerland", "Europe/Zurich"),
        ("Bern", "Switzerland", "Europe/Zurich"),
        ("Graz", "Austria", "Europe/Vienna"),
        ("Salzburg", "Austria", "Europe/Vienna"),
        ("Kraków", "Poland", "Europe/Warsaw"),
        ("Wrocław", "Poland", "Europe/Warsaw"),
        ("Gdańsk", "Poland", "Europe/Warsaw"),
        ("Brno", "Czechia", "Europe/Prague"),
        ("Gothenburg", "Sweden", "Europe/Stockholm"),
        ("Malmö", "Sweden", "Europe/Stockholm"),
        ("Aarhus", "Denmark", "Europe/Copenhagen"),
        ("Bergen", "Norway", "Europe/Oslo"),
        ("Trondheim", "Norway", "Europe/Oslo"),
        ("Tampere", "Finland", "Europe/Helsinki"),
        ("Thessaloniki", "Greece", "Europe/Athens"),
        ("Cluj", "Romania", "Europe/Bucharest"),
        ("Ankara", "Türkiye", "Europe/Istanbul"),
        ("Izmir", "Türkiye", "Europe/Istanbul"),
        ("Saint Petersburg", "Russia", "Europe/Moscow"),
        ("Lviv", "Ukraine", "Europe/Kyiv"),
        ("Tel Aviv", "Israel", "Asia/Jerusalem"),
        ("Abu Dhabi", "United Arab Emirates", "Asia/Dubai"),
        ("Sharjah", "United Arab Emirates", "Asia/Dubai"),
        ("Jeddah", "Saudi Arabia", "Asia/Riyadh"),
        ("Mecca", "Saudi Arabia", "Asia/Riyadh"),
        ("Mumbai", "India", "Asia/Kolkata"),
        ("Delhi", "India", "Asia/Kolkata"),
        ("New Delhi", "India", "Asia/Kolkata"),
        ("Bengaluru", "India", "Asia/Kolkata"),
        ("Bangalore", "India", "Asia/Kolkata"),
        ("Hyderabad", "India", "Asia/Kolkata"),
        ("Chennai", "India", "Asia/Kolkata"),
        ("Pune", "India", "Asia/Kolkata"),
        ("Ahmedabad", "India", "Asia/Kolkata"),
        ("Gurgaon", "India", "Asia/Kolkata"),
        ("Noida", "India", "Asia/Kolkata"),
        ("Lahore", "Pakistan", "Asia/Karachi"),
        ("Islamabad", "Pakistan", "Asia/Karachi"),
        ("Beijing", "China", "Asia/Shanghai"),
        ("Shenzhen", "China", "Asia/Shanghai"),
        ("Guangzhou", "China", "Asia/Shanghai"),
        ("Hangzhou", "China", "Asia/Shanghai"),
        ("Chengdu", "China", "Asia/Shanghai"),
        ("Osaka", "Japan", "Asia/Tokyo"),
        ("Kyoto", "Japan", "Asia/Tokyo"),
        ("Nagoya", "Japan", "Asia/Tokyo"),
        ("Fukuoka", "Japan", "Asia/Tokyo"),
        ("Busan", "South Korea", "Asia/Seoul"),
        ("Kuala Lumpur", "Malaysia", "Asia/Kuala_Lumpur"),
        ("Hanoi", "Vietnam", "Asia/Ho_Chi_Minh"),
        ("Saigon", "Vietnam", "Asia/Ho_Chi_Minh"),
        ("Bali", "Indonesia", "Asia/Makassar"),
        ("Denpasar", "Indonesia", "Asia/Makassar"),
        ("Cebu", "Philippines", "Asia/Manila"),
        ("Canberra", "Australia", "Australia/Sydney"),
        ("Adelaide", "Australia", "Australia/Adelaide"),
        ("Gold Coast", "Australia", "Australia/Brisbane"),
        ("Hobart", "Australia", "Australia/Hobart"),
        ("Wellington", "New Zealand", "Pacific/Auckland"),
        ("Christchurch", "New Zealand", "Pacific/Auckland"),
        ("Cape Town", "South Africa", "Africa/Johannesburg"),
        ("Durban", "South Africa", "Africa/Johannesburg"),
        ("Pretoria", "South Africa", "Africa/Johannesburg"),
        ("Abuja", "Nigeria", "Africa/Lagos"),
        ("Marrakesh", "Morocco", "Africa/Casablanca"),
        ("Rabat", "Morocco", "Africa/Casablanca"),
        ("Alexandria", "Egypt", "Africa/Cairo"),
        ("Rio de Janeiro", "Brazil", "America/Sao_Paulo"),
        ("Brasília", "Brazil", "America/Sao_Paulo"),
        ("Belo Horizonte", "Brazil", "America/Sao_Paulo"),
        ("Curitiba", "Brazil", "America/Sao_Paulo"),
        ("Porto Alegre", "Brazil", "America/Sao_Paulo"),
        ("Medellín", "Colombia", "America/Bogota"),
        ("Cali", "Colombia", "America/Bogota"),
        ("Guadalajara", "Mexico", "America/Mexico_City"),
        ("Monterrey", "Mexico", "America/Monterrey"),
        ("Cancún", "Mexico", "America/Cancun"),
        ("Valparaíso", "Chile", "America/Santiago"),
        ("Córdoba", "Argentina", "America/Argentina/Cordoba"),
        ("Honolulu", "United States", "Pacific/Honolulu"),
        ("Anchorage", "United States", "America/Anchorage"),

        // More US cities
        ("Phoenix", "United States", "America/Phoenix"),
        ("Tucson", "United States", "America/Phoenix"),
        ("Detroit", "United States", "America/New_York"),
        ("Indianapolis", "United States", "America/New_York"),
        ("Columbus", "United States", "America/New_York"),
        ("Baltimore", "United States", "America/New_York"),
        ("Richmond", "United States", "America/New_York"),
        ("Buffalo", "United States", "America/New_York"),
        ("Jacksonville", "United States", "America/New_York"),
        ("Tampa", "United States", "America/New_York"),
        ("San Antonio", "United States", "America/Chicago"),
        ("Memphis", "United States", "America/Chicago"),
        ("Milwaukee", "United States", "America/Chicago"),
        ("St Louis", "United States", "America/Chicago"),
        ("Oklahoma City", "United States", "America/Chicago"),
        ("Omaha", "United States", "America/Chicago"),
        ("Louisville", "United States", "America/New_York"),
        ("Des Moines", "United States", "America/Chicago"),
        ("Madison", "United States", "America/Chicago"),
        ("Albuquerque", "United States", "America/Denver"),
        ("Colorado Springs", "United States", "America/Denver"),
        ("El Paso", "United States", "America/Denver"),
        ("Boise", "United States", "America/Boise"),
        ("Reno", "United States", "America/Los_Angeles"),
        ("Sacramento", "United States", "America/Los_Angeles"),
        ("Oakland", "United States", "America/Los_Angeles"),
        ("Fresno", "United States", "America/Los_Angeles"),

        // More Canada
        ("Winnipeg", "Canada", "America/Winnipeg"),
        ("Saskatoon", "Canada", "America/Regina"),
        ("Regina", "Canada", "America/Regina"),
        ("Victoria", "Canada", "America/Vancouver"),
        ("Edmonton", "Canada", "America/Edmonton"),
        ("Halifax", "Canada", "America/Halifax"),

        // Mexico, Central America & Caribbean
        ("Tijuana", "Mexico", "America/Tijuana"),
        ("Puebla", "Mexico", "America/Mexico_City"),
        ("Mérida", "Mexico", "America/Merida"),
        ("Guatemala City", "Guatemala", "America/Guatemala"),
        ("San José", "Costa Rica", "America/Costa_Rica"),
        ("Panama City", "Panama", "America/Panama"),
        ("San Salvador", "El Salvador", "America/El_Salvador"),
        ("Tegucigalpa", "Honduras", "America/Tegucigalpa"),
        ("Managua", "Nicaragua", "America/Managua"),
        ("Havana", "Cuba", "America/Havana"),
        ("Santo Domingo", "Dominican Republic", "America/Santo_Domingo"),
        ("San Juan", "Puerto Rico", "America/Puerto_Rico"),
        ("Kingston", "Jamaica", "America/Jamaica"),
        ("Nassau", "Bahamas", "America/Nassau"),

        // More South America
        ("Caracas", "Venezuela", "America/Caracas"),
        ("Quito", "Ecuador", "America/Guayaquil"),
        ("Guayaquil", "Ecuador", "America/Guayaquil"),
        ("La Paz", "Bolivia", "America/La_Paz"),
        ("Montevideo", "Uruguay", "America/Montevideo"),
        ("Asunción", "Paraguay", "America/Asuncion"),
        ("Recife", "Brazil", "America/Recife"),
        ("Salvador", "Brazil", "America/Bahia"),
        ("Manaus", "Brazil", "America/Manaus"),
        ("Georgetown", "Guyana", "America/Guyana"),
        ("Paramaribo", "Suriname", "America/Paramaribo"),
        ("Barranquilla", "Colombia", "America/Bogota"),
        ("Arequipa", "Peru", "America/Lima"),
        ("Mendoza", "Argentina", "America/Argentina/Mendoza"),
        ("Rosario", "Argentina", "America/Argentina/Buenos_Aires"),
        ("Bridgetown", "Barbados", "America/Barbados"),
        ("Port of Spain", "Trinidad and Tobago", "America/Port_of_Spain"),

        // More Europe
        ("Vilnius", "Lithuania", "Europe/Vilnius"),
        ("Riga", "Latvia", "Europe/Riga"),
        ("Tallinn", "Estonia", "Europe/Tallinn"),
        ("Sofia", "Bulgaria", "Europe/Sofia"),
        ("Zagreb", "Croatia", "Europe/Zagreb"),
        ("Belgrade", "Serbia", "Europe/Belgrade"),
        ("Ljubljana", "Slovenia", "Europe/Ljubljana"),
        ("Sarajevo", "Bosnia and Herzegovina", "Europe/Sarajevo"),
        ("Skopje", "North Macedonia", "Europe/Skopje"),
        ("Podgorica", "Montenegro", "Europe/Podgorica"),
        ("Tirana", "Albania", "Europe/Tirane"),
        ("Bratislava", "Slovakia", "Europe/Bratislava"),
        ("Reykjavik", "Iceland", "Atlantic/Reykjavik"),
        ("Valletta", "Malta", "Europe/Malta"),
        ("Luxembourg City", "Luxembourg", "Europe/Luxembourg"),
        ("Monaco", "Monaco", "Europe/Monaco"),
        ("Chisinau", "Moldova", "Europe/Chisinau"),
        ("Minsk", "Belarus", "Europe/Minsk"),

        // More Asia
        ("Colombo", "Sri Lanka", "Asia/Colombo"),
        ("Dhaka", "Bangladesh", "Asia/Dhaka"),
        ("Yangon", "Myanmar", "Asia/Yangon"),
        ("Phnom Penh", "Cambodia", "Asia/Phnom_Penh"),
        ("Vientiane", "Laos", "Asia/Vientiane"),
        ("Ulaanbaatar", "Mongolia", "Asia/Ulaanbaatar"),
        ("Almaty", "Kazakhstan", "Asia/Almaty"),
        ("Tashkent", "Uzbekistan", "Asia/Tashkent"),
        ("Baku", "Azerbaijan", "Asia/Baku"),
        ("Tbilisi", "Georgia", "Asia/Tbilisi"),
        ("Yerevan", "Armenia", "Asia/Yerevan"),
        ("Amman", "Jordan", "Asia/Amman"),
        ("Beirut", "Lebanon", "Asia/Beirut"),
        ("Doha", "Qatar", "Asia/Qatar"),
        ("Manama", "Bahrain", "Asia/Bahrain"),
        ("Kuwait City", "Kuwait", "Asia/Kuwait"),
        ("Muscat", "Oman", "Asia/Muscat"),
        ("Kabul", "Afghanistan", "Asia/Kabul"),

        // More Africa
        ("Tunis", "Tunisia", "Africa/Tunis"),
        ("Algiers", "Algeria", "Africa/Algiers"),
        ("Tripoli", "Libya", "Africa/Tripoli"),
        ("Khartoum", "Sudan", "Africa/Khartoum"),
        ("Addis Ababa", "Ethiopia", "Africa/Addis_Ababa"),
        ("Dar es Salaam", "Tanzania", "Africa/Dar_es_Salaam"),
        ("Kampala", "Uganda", "Africa/Kampala"),
        ("Kigali", "Rwanda", "Africa/Kigali"),
        ("Kinshasa", "DR Congo", "Africa/Kinshasa"),
        ("Luanda", "Angola", "Africa/Luanda"),
        ("Lusaka", "Zambia", "Africa/Lusaka"),
        ("Maputo", "Mozambique", "Africa/Maputo"),
        ("Dakar", "Senegal", "Africa/Dakar"),
        ("Accra", "Ghana", "Africa/Accra"),

        // More Oceania
        ("Perth", "Australia", "Australia/Perth"),
        ("Darwin", "Australia", "Australia/Darwin"),
        ("Suva", "Fiji", "Pacific/Fiji"),
        ("Port Moresby", "Papua New Guinea", "Pacific/Port_Moresby"),
        ("Nouméa", "New Caledonia", "Pacific/Noumea"),
        ("Apia", "Samoa", "Pacific/Apia"),
        ("Nukuʻalofa", "Tonga", "Pacific/Tongatapu"),
    ]

    /// Legacy / non-city identifiers we hide from the picker.
    private static let hiddenPrefixes = [
        "Etc/", "US/", "Canada/", "Mexico/", "Brazil/", "Chile/", "SystemV/", "posix/", "right/",
    ]

    private static let hiddenExact: Set<String> = [
        "GMT", "GMT0", "GMT+0", "GMT-0", "Greenwich", "Universal", "Zulu", "UCT",
        "EST", "MST", "HST", "EST5EDT", "CST6CDT", "MST7MDT", "PST8PDT", "EET", "WET", "CET", "MET",
        "Egypt", "Eire", "Hongkong", "Iceland", "Iran", "Israel", "Jamaica", "Japan", "Kwajalein",
        "Libya", "NZ", "NZ-CHAT", "Navajo", "PRC", "Poland", "Portugal", "ROC", "ROK", "Singapore",
        "Turkey", "W-SU", "Cuba", "Factory", "localtime",
    ]

    static func defaultName(for identifier: String) -> String {
        if identifier == "UTC" { return "UTC" }
        let last = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    private static func regionName(for identifier: String) -> String {
        let parts = identifier.split(separator: "/").map(String.init)
        guard parts.count > 1 else { return "Coordinated Universal Time" }
        if parts.count >= 3 { return "\(parts[0]) · \(parts[1].replacingOccurrences(of: "_", with: " "))" }
        return parts[0]
    }

    /// The country/region label for a saved city, shown alongside its name in the bar.
    /// Prefers the exact catalog entry (so "Tegucigalpa" reads "Honduras" rather than the
    /// bare continent), falling back to the generic region derived from the zone identifier —
    /// which still applies after a rename, since the lookup by name then misses.
    static func country(forName name: String, timeZoneID: String) -> String {
        if let entry = all.first(where: {
            $0.timeZoneID == timeZoneID && $0.display.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return entry.region
        }
        return regionName(for: timeZoneID)
    }

    /// The named zone abbreviations, in listed order.
    static let standardEntries: [CatalogEntry] = {
        standards.enumerated().compactMap { i, s in
            let (abbr, desc, zone, extra) = s
            guard TimeZone(identifier: zone) != nil else { return nil }
            return CatalogEntry(id: "s:\(abbr):\(zone)", display: abbr, region: desc,
                                timeZoneID: zone, rank: i,
                                terms: "\(abbr) \(desc) \(zone) \(extra)".lowercased(),
                                isStandard: true)
        }
    }()

    /// Cities only, ranked so the useful stuff surfaces first.
    static let all: [CatalogEntry] = {
        var out: [CatalogEntry] = []
        var seenDisplay = Set<String>()

        // 1. Featured, in the order listed.
        for (i, id) in featured.enumerated() where TimeZone(identifier: id) != nil {
            let name = defaultName(for: id)
            let region = id == "UTC" ? "Coordinated Universal Time" : regionName(for: id)
            out.append(CatalogEntry(id: "f:\(id)", display: name, region: region,
                                    timeZoneID: id, rank: i,
                                    terms: "\(name) \(region) \(id)".lowercased()))
            seenDisplay.insert(name.lowercased())
        }

        // 2. Named aliases (big cities sharing a zone).
        for (i, a) in aliases.enumerated() where TimeZone(identifier: a.2) != nil {
            guard !seenDisplay.contains(a.0.lowercased()) else { continue }
            out.append(CatalogEntry(id: "a:\(a.0)", display: a.0, region: a.1,
                                    timeZoneID: a.2, rank: 1_000 + i,
                                    terms: "\(a.0) \(a.1) \(a.2)".lowercased()))
            seenDisplay.insert(a.0.lowercased())
        }

        // 3. Every remaining zone from the system database.
        for id in TimeZone.knownTimeZoneIdentifiers.sorted() {
            if hiddenExact.contains(id) { continue }
            if hiddenPrefixes.contains(where: { id.hasPrefix($0) }) { continue }
            if !id.contains("/") { continue }   // bare UTC/GMT are standard zones, not cities
            let name = defaultName(for: id)
            if seenDisplay.contains(name.lowercased()) { continue }
            let region = regionName(for: id)
            out.append(CatalogEntry(id: "z:\(id)", display: name, region: region,
                                    timeZoneID: id, rank: 5_000,
                                    terms: "\(name) \(region) \(id)".lowercased()))
            seenDisplay.insert(name.lowercased())
        }
        return out
    }()

    private static func rank(_ e: CatalogEntry, against q: String) -> Int? {
        let display = e.display.lowercased()
        let score: Int
        if display == q { score = 0 }
        else if display.hasPrefix(q) { score = 1 }
        else if display.contains(q) { score = 2 }
        else if matchesWord(e.terms, q) { score = 3 }
        else if e.terms.contains(q) { score = 4 }
        else { return nil }
        return score * 100_000 + e.rank
    }

    /// True when `q` starts any whitespace-separated word in `haystack`, so "pt" hits
    /// "pt pst pdt pacific" but not "…hampton".
    private static func matchesWord(_ haystack: String, _ q: String) -> Bool {
        haystack.split(separator: " ").contains { $0.hasPrefix(q) }
    }

    /// Search results split into the two sections the picker shows.
    /// Standard zones always come first — that's the point of the section.
    static func search(_ query: String, limit: Int = 60)
    -> (standard: [CatalogEntry], cities: [CatalogEntry]) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !q.isEmpty else {
            return (Array(standardEntries.prefix(standardPreviewCount)), Array(all.prefix(limit)))
        }

        func matches(_ pool: [CatalogEntry]) -> [CatalogEntry] {
            pool.compactMap { e in rank(e, against: q).map { (e, $0) } }
                .sorted { $0.1 < $1.1 }
                .prefix(limit)
                .map(\.0)
        }
        return (matches(standardEntries), matches(all))
    }

    /// Every selectable entry, standard zones first. Used for validation.
    static var everything: [CatalogEntry] { standardEntries + all }

}
