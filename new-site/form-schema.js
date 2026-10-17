/* Original PVG enquiry fields, options and validation requirements. */
(function(root){const schema={
  "request": {
    "website": {
      "label": "Website",
      "type": "text",
      "required": false
    },
    "latitude": {
      "label": "Latitude",
      "type": "hidden",
      "required": false
    },
    "longitude": {
      "label": "Longitude",
      "type": "hidden",
      "required": false
    },
    "gps_accuracy": {
      "label": "Gps Accuracy",
      "type": "hidden",
      "required": false
    },
    "requirement_type": {
      "label": "Requirement Type",
      "type": "select",
      "required": true,
      "options": [
        "Low battery / stranded vehicle",
        "Mobile EV charging",
        "Fleet charging",
        "Depot support",
        "Event charging",
        "Temporary project location",
        "Residential or community requirement",
        "Pilot programme",
        "Other"
      ]
    },
    "customer_type": {
      "label": "Customer Type",
      "type": "select",
      "required": false,
      "options": [
        "Individual EV owner",
        "Fleet operator",
        "Apartment community",
        "Commercial property",
        "Office or IT park",
        "Taxi or mobility operator",
        "Logistics operator",
        "Government or smart-city body"
      ]
    },
    "phone": {
      "label": "Mobile Number",
      "type": "tel",
      "required": true
    },
    "name": {
      "label": "Name",
      "type": "text",
      "required": true
    },
    "city": {
      "label": "Current Area",
      "type": "text",
      "required": true
    },
    "location_type": {
      "label": "Location Type",
      "type": "select",
      "required": true,
      "options": [
        "Roadside or stranded location",
        "Home or apartment parking",
        "Office or IT park",
        "Fleet depot",
        "Commercial parking location",
        "Highway or route location",
        "Event or temporary site"
      ]
    },
    "address": {
      "label": "Landmark or Exact Spot",
      "type": "textarea",
      "required": true
    },
    "gps_location": {
      "label": "GPS Location",
      "type": "text",
      "required": true
    },
    "vehicle_category": {
      "label": "Vehicle Category",
      "type": "select",
      "required": true,
      "options": [
        "Electric car",
        "Electric taxi",
        "Electric three-wheeler",
        "Electric two-wheeler",
        "Electric van",
        "Electric truck or logistics vehicle",
        "Mixed EV fleet"
      ]
    },
    "vehicle_model": {
      "label": "Vehicle Make / Model",
      "type": "text",
      "required": false
    },
    "vehicle_count": {
      "label": "Number of Vehicles",
      "type": "number",
      "required": false,
      "min": "1"
    },
    "current_battery_level": {
      "label": "Current Battery Level",
      "type": "number",
      "required": false,
      "min": "0",
      "max": "100"
    },
    "charging_details": {
      "label": "What happened?",
      "type": "textarea",
      "required": false
    },
    "email": {
      "label": "Email",
      "type": "email",
      "required": false
    },
    "company": {
      "label": "Company / Community",
      "type": "text",
      "required": false
    },
    "connector_type": {
      "label": "Connector / Charging Standard",
      "type": "select",
      "required": false,
      "options": [
        "Known connector type",
        "Not sure",
        "To be confirmed by PVG-EV"
      ]
    },
    "battery_status": {
      "label": "Battery Status",
      "type": "select",
      "required": false,
      "options": [
        "Low battery now",
        "Scheduled top-up required",
        "Fleet planning requirement",
        "Commercial site planning requirement"
      ]
    },
    "charging_need": {
      "label": "Charging Need",
      "type": "select",
      "required": false,
      "options": [
        "Immediate assistance",
        "Same-day charging",
        "Scheduled mobile charging",
        "Regular fleet charging support",
        "Temporary event charging",
        "Site assessment for future charging"
      ]
    },
    "preferred_window": {
      "label": "Preferred Charging Window",
      "type": "select",
      "required": false,
      "options": [
        "Morning",
        "Afternoon",
        "Evening",
        "Night / depot downtime",
        "Flexible"
      ]
    },
    "preferred_time": {
      "label": "Preferred Time",
      "type": "time",
      "required": false
    },
    "requirement_scope": {
      "label": "Requirement Scope",
      "type": "select",
      "required": false,
      "options": [
        "Individual vehicle requirement",
        "Fleet requirement",
        "Site or community requirement",
        "Institutional or pilot requirement"
      ]
    },
    "target_date": {
      "label": "Target Date",
      "type": "date",
      "required": false
    },
    "pilot_interest": {
      "label": "Pilot Interest",
      "type": "select",
      "required": false,
      "options": [
        "I want to join the Chennai pilot",
        "I want future service updates",
        "I need a commercial discussion",
        "I only want general information"
      ]
    },
    "additional_notes": {
      "label": "Additional Notes",
      "type": "textarea",
      "required": false
    },
    "consent": {
      "label": "I understand that this is a requirement submission for PVG-EV review and does not confirm service availability, pricing, response time or live charging support.",
      "type": "checkbox",
      "required": true
    }
  },
  "contact": {
    "name": {
      "label": "Your name",
      "type": "text",
      "required": true
    },
    "email": {
      "label": "Email address",
      "type": "email",
      "required": false
    },
    "telephone": {
      "label": "Phone number",
      "type": "tel",
      "required": true
    },
    "company": {
      "label": "Company / Organisation",
      "type": "text",
      "required": false
    },
    "requirement": {
      "label": "What can we help you with?",
      "type": "select",
      "required": true,
      "options": [
        "Request Mobile Charging",
        "Pilot Assessment",
        "Join Chennai Pilot",
        "General Enquiry",
        "Fleet Charging Solutions",
        "Commercial Charging",
        "Apartment / Residential Community",
        "Partnership / Setrans"
      ]
    },
    "city": {
      "label": "Deployment location",
      "type": "select",
      "required": true,
      "options": [
        "Chennai",
        "Coimbatore",
        "Madurai",
        "Trichy",
        "Salem",
        "Tirunelveli",
        "Erode",
        "Thanjavur",
        "Other Tamil Nadu location"
      ]
    },
    "preferred_date": {
      "label": "Preferred date of contact",
      "type": "date",
      "required": false
    },
    "contact_time": {
      "label": "Preferred time",
      "type": "select",
      "required": false,
      "options": [
        "Morning",
        "Afternoon",
        "Evening",
        "Any suitable time"
      ]
    },
    "message": {
      "label": "Message",
      "type": "textarea",
      "required": true
    },
    "consent": {
      "label": "Contact consent",
      "type": "checkbox",
      "required": true
    }
  },
  "fleet": {
    "company": {
      "label": "Company / Organisation",
      "type": "text",
      "required": true
    },
    "number-of-evs": {
      "label": "Number of EVs",
      "type": "number",
      "required": true,
      "min": "1"
    },
    "fleet-type": {
      "label": "Fleet Type",
      "type": "select",
      "required": false,
      "options": [
        "Taxi / mobility fleet",
        "Logistics or delivery fleet",
        "Corporate fleet",
        "Apartment or shuttle fleet",
        "Mixed fleet"
      ]
    },
    "daily-utilisation": {
      "label": "Daily Utilisation",
      "type": "select",
      "required": false,
      "options": [
        "Under 50 km/day",
        "50–100 km/day",
        "100–200 km/day",
        "Above 200 km/day"
      ]
    },
    "main-charging-challenge": {
      "label": "Main Charging Challenge",
      "type": "select",
      "required": true,
      "options": [
        "Depot charging capacity",
        "Vehicle downtime",
        "Route charging access",
        "Temporary fleet expansion",
        "Mixed mobile and fixed charging"
      ]
    },
    "charging-window": {
      "label": "Preferred Charging Window",
      "type": "select",
      "required": false,
      "options": [
        "Daytime",
        "Night / overnight",
        "Between trips",
        "Emergency / ad hoc"
      ]
    },
    "preferred-model": {
      "label": "Preferred Model",
      "type": "select",
      "required": false,
      "options": [
        "Mobile charging",
        "Depot charging",
        "Hybrid charging",
        "Need PVG-EV recommendation"
      ]
    },
    "city": {
      "label": "City",
      "type": "text",
      "required": true
    },
    "operating-base": {
      "label": "Depot / Operating Base",
      "type": "text",
      "required": false
    },
    "name": {
      "label": "Full Name",
      "type": "text",
      "required": true
    },
    "telephone": {
      "label": "Phone Number",
      "type": "tel",
      "required": true
    },
    "email": {
      "label": "Email",
      "type": "email",
      "required": true
    },
    "message": {
      "label": "Tell us more about your fleet and requirements",
      "type": "textarea",
      "required": true
    },
    "consent": {
      "label": "Contact consent",
      "type": "checkbox",
      "required": true
    },
    "vehicle_model": {
      "label": "Vehicle makes / models",
      "type": "text",
      "required": false
    }
  },
  "pilot": {
    "name": {
      "label": "Full name",
      "type": "text",
      "required": true
    },
    "company": {
      "label": "Company / organisation",
      "type": "text",
      "required": true
    },
    "job-title": {
      "label": "Job title",
      "type": "text",
      "required": false
    },
    "email": {
      "label": "Email",
      "type": "email",
      "required": true
    },
    "telephone": {
      "label": "Mobile number",
      "type": "tel",
      "required": true
    },
    "city": {
      "label": "City",
      "type": "text",
      "required": true
    },
    "customer-type": {
      "label": "Customer type",
      "type": "select",
      "required": true,
      "options": [
        "EV fleet operator",
        "Taxi and mobility operator",
        "Logistics operator",
        "Corporate campus",
        "Commercial property",
        "Apartment community",
        "Dealership",
        "Event operator",
        "Institution or location partner",
        "Other"
      ]
    },
    "number-of-evs": {
      "label": "Number of EVs",
      "type": "text",
      "required": true
    },
    "vehicle-types": {
      "label": "Vehicle types",
      "type": "text",
      "required": true
    },
    "current-charging-method": {
      "label": "Current charging method",
      "type": "text",
      "required": true
    },
    "preferred-charging-location": {
      "label": "Preferred charging location",
      "type": "text",
      "required": true
    },
    "expected-charging-frequency": {
      "label": "Expected charging frequency",
      "type": "text",
      "required": true
    },
    "fleet-operating-hours": {
      "label": "Fleet operating hours",
      "type": "text",
      "required": false
    },
    "message": {
      "label": "Main charging challenge",
      "type": "textarea",
      "required": true
    },
    "preferred-pilot-location": {
      "label": "Preferred pilot location",
      "type": "text",
      "required": true
    },
    "expected-use-case": {
      "label": "Expected use case",
      "type": "select",
      "required": true,
      "options": [
        "Fleet charging support",
        "Commercial-site charging",
        "Apartment or community support",
        "Temporary event charging",
        "Low-charge vehicle assessment",
        "Dealership demonstration",
        "Other"
      ]
    },
    "additional-notes": {
      "label": "Additional notes",
      "type": "textarea",
      "required": false
    },
    "interested-in-pilot-participation": {
      "label": "Interested in pilot participation",
      "type": "checkbox",
      "required": false
    },
    "interested-in-strategic-partnership": {
      "label": "Interested in strategic partnership",
      "type": "checkbox",
      "required": false
    },
    "interested-in-fleet-charging-assessment": {
      "label": "Interested in fleet charging assessment",
      "type": "checkbox",
      "required": false
    },
    "interested-in-launch-updates": {
      "label": "Interested in launch updates",
      "type": "checkbox",
      "required": false
    },
    "consent-to-receive-updates": {
      "label": "I consent to PVG-EV contacting me about this pilot registration and related requirement review.",
      "type": "checkbox",
      "required": true
    }
  }
};if(typeof module==="object"&&module.exports)module.exports=schema;else root.PVGFormSchema=schema;})(typeof globalThis!=="undefined"?globalThis:this);
