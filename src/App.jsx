
const App = () => {

  const city = ['Dhaka', 'Chittagong', 'Khulna', 'Rajshahi'];
  return (
    <div>
       <h1>Hello</h1>
     <ul>
      {
       
        city.map((item,i)=>{
          return <li key={i.toString}>{item}</li>
        })
      }
     </ul>
    </div>
  );
};

export default App;