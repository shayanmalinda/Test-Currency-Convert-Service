# Currency Convert Service

### /convert-currency

#### POST

##### Summary:

Get exchange rates based on the date and base currency.

##### Parameters

<table>
<tr>
<th>Name</th>
<th>Located in</th>
<th>Description</th>
<th>Required</th>
<th>Schema</th>
</tr>
<tr>
<td>payload</td>
<td>body</td>
<td>Currency convert payload</td>
<td>Yes</td>
<td>

```json
{
    "baseCode": "USD",
    "date": "2023-01-01"
}
```
</td>
</tr>
</table>

##### Responses

<table>
<tr>
<th>Code</th>
<th>Description</th>
</tr>
<tr>
<td>201</td>
<td>Created


```json
[
    {
        "currencyCode": "LKR",
        "exchangeRate": "200.00"
    },
    {
        "currencyCode": "EUR",
        "exchangeRate": "55.00"
    }
]
```
</td>
</tr>
<tr>
<td>500</td>
<td>InternalServerError</td>
</tr>
</table>