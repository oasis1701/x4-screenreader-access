'''
Miscellaneous support classes for the X4 Python Pipe Server.
'''

class Client_Garbage_Collected(Exception):
    '''
    Custom exception raised when the pipe client sends a 'garbage_collected'
    message, indicating the X4 side closed its pipe connection.
    '''
    pass
