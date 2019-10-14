# TFL Journey Cost

Fetches theoretical cost of TFL journies from TFL journey history CSV.

## Getting Started

Download all files, place journey history in `.\inputs\xyz.csv`, then run `.\tfl.ps1`.
Currently, the script calculates peak and off peak hours, including all UK bank holdiays as off peak (using the [GOV.UK](https://www.gov.uk/bank-holidays.json) API). Hopper Fare discounts are currently ignored.

### Prerequisites

You will need [Powershell](https://github.com/PowerShell/PowerShell#get-powershell) and an Application ID and Application Key from [TFL](https://api-portal.tfl.gov.uk).

### Installing

Download all files, and place your journey history csv in the `.\inputs` folder (format should match the example).

Next create a copy of `.\params.json.example` called `.\params.json` and enter your Application ID and Application Key in the placeholders. You may also adjust the other variables as necessary.
```
"app_id": "ABCD123"
```

Run the script from a new Powershell window, in the location of `.\tfl.ps1`
```
PS C:\Users\username\scripts\tfl_journey_history> .\tfl
```

## Contributing

Feel free to get in touch with suggestions or contributions.

## Authors

* **Simon England** - [Website](https://simonengland.net)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
