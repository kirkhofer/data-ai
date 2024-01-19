import os
import requests

class AOAIBalancer:
    endpoints=[]
    pointers=[]
    models=[]

    def __init__(self,endpoints=[]):
        if len(endpoints)==0:
            endpoints.append({"endpoint":os.getenv('OPENAI_API_BASE'),"key":os.getenv('OPENAI_API_KEY')})
        
        self.endpoints=endpoints

        for endpoint in self.endpoints:
            print(f"endpoint: {endpoint}")
            # As of 1.X you cannot easily list deployments so we have to do this with the REST API
            headers={"Content-Type":"application/json","api-key":endpoint['key']}
            uri = f"{endpoint['endpoint'] }/openai/deployments?api-version=2022-12-01"    
            request = requests.get(uri, headers=headers)
            response = request.json()

            for dep in response['data']:
                self.models.append({"endpoint":endpoint['endpoint'],"key":endpoint['key'],"model":dep['model'],"deployment":dep['id']})
        
        # Get distinct modelNames in the endpoints list
        pts = list(set([x['model'] for x in self.models]))
        for pt in pts:
            x=len([x for x in self.models if x['model']==pt])
            self.pointers.append({"model":pt,"pointer":0,"count":x})

    def getModel(self,model="text-davinci-003"):
        pointer=next((m for m in self.pointers if m['model'] == model), None) 
        mods=list(filter(lambda x: x['model'] == model, self.models))
        return mods[pointer['pointer']]

    def incrementModel(self,model="text-davinci-003"):
        pointer=next((m for m in self.pointers if m['model'] == model), None) 
        key = pointer['pointer']
        if key < pointer['count']-1:
            key+=1
        else:
            key=0
        pointer['pointer']=key